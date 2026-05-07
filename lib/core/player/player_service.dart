import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/track.dart';
import 'cache_service.dart';
import 'equalizer_presets.dart';
import 'equalizer_runtime_policy.dart';
import 'equalizer_state.dart';
import 'playback_autoplay_policy.dart';
import 'playback_completion_policy.dart';
import 'queue_preparation_policy.dart';

class MusicPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler, ChangeNotifier {
  static const _historyStorageKey = 'play_history_tracks';
  static const _sessionStorageKey = 'player_session_state';
  static const _trackProgressStorageKey = 'track_resume_positions';
  static const _lyricOffsetStorageKey = 'track_lyric_offsets';
  static const _equalizerPresetStorageKey = 'player_equalizer_preset';
  static const _equalizerStateStorageKey = 'player_equalizer_state_v2';
  static const _maxHistoryLength = 100;
  static const _maxTrackResumeEntries = 300;

  final AndroidEqualizer _equalizer = AndroidEqualizer();
  late final AudioPlayer _player = _buildAudioPlayer();
  late final Dio _networkDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  List<Track> _queue = [];
  final List<Track> _history = [];
  int _currentIndex = 0;
  String _preparedQueueSignature = '';
  int _suppressedIndexEvents = 0;
  String? _token;
  String? _baseUrl;
  CacheService? _cacheService;
  int? _maxCacheBytes;
  SharedPreferences? _prefs;
  final Map<String, int> _trackResumePositions = {};
  final Map<String, int> _lyricOffsets = {};
  bool _pendingPlayAfterAuth = false;
  bool _isSyncingExclusiveModes = false;
  bool _isHandlingCompletion = false;
  _ExclusivePlaybackMode? _lastExclusiveMode;
  String? _activeTrackId;
  List<_LyricLine> _currentLyrics = [];
  String? _currentRawLyrics;
  int _lastLyricIndex = -1;
  Duration? _pendingRestorePosition;
  bool _pendingRestoreShouldResume = false;
  Timer? _sleepTimer;
  Timer? _sleepTicker;
  Duration? _sleepRemaining;
  int _lastPersistedSecond = -1;
  EqualizerStateSnapshot _equalizerState = EqualizerStateSnapshot.empty();
  AndroidEqualizerParameters? _equalizerParameters;
  Future<void> Function(String key, Object? value)? _remotePreferenceSync;
  final StreamController<Duration?> _sleepTimerController =
      StreamController<Duration?>.broadcast();

  MusicPlayerHandler() {
    _initAudioSession();
    _player.playbackEventStream.listen(_broadcastState);
    _player.shuffleModeEnabledStream.listen((_) async {
      await _syncExclusivePlaybackModes();
      _broadcastState(null);
    });
    _player.loopModeStream.listen((_) async {
      await _syncExclusivePlaybackModes();
      _broadcastState(null);
    });
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (!_isHandlingCompletion) {
          _isHandlingCompletion = true;
          unawaited(_handlePlaybackCompleted());
        }
      } else {
        _isHandlingCompletion = false;
      }
    });
    _player.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= _queue.length) {
        return;
      }
      if (_suppressedIndexEvents > 0) {
        _suppressedIndexEvents--;
        _currentIndex = index;
        _broadcastState(null);
        return;
      }
      if (_currentIndex == index && _activeTrackId == _queue[index].id) {
        return;
      }
      unawaited(_handleCurrentIndexChanged(index));
    });

    _player.positionStream.listen(_updateLyricInMetadata);
    _player.positionStream.listen((position) {
      final wholeSecond = position.inSeconds;
      if (wholeSecond >= 0 && wholeSecond != _lastPersistedSecond) {
        _lastPersistedSecond = wholeSecond;
        if (wholeSecond == 0 || wholeSecond % 5 == 0) {
          _saveTrackProgress(position: position);
          unawaited(_persistSession());
        }
      }
    });
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      debugPrint('Error config AudioSession: $e');
    }
  }

  void setAuth(String token, String baseUrl, {bool autoPlayOnRestore = false}) {
    debugPrint('Setting player auth: $baseUrl');
    _token = token;
    _baseUrl = baseUrl;
    _preparedQueueSignature = '';

    if (_pendingPlayAfterAuth) {
      debugPrint('Auth received, retrying pending playback...');
      _pendingPlayAfterAuth = false;
      unawaited(_playCurrentTrack());
      return;
    }

    if (_queue.isNotEmpty &&
        (_pendingRestorePosition != null || _player.audioSource == null)) {
      final shouldAutoPlay = resolveAutoPlayBehavior(
        trigger: PlaybackResumeTrigger.launchRestore,
        wasPlaying: _pendingRestoreShouldResume,
        autoPlayOnLaunchRestore: autoPlayOnRestore,
      );
      unawaited(
        _playCurrentTrack(
          autoPlay: shouldAutoPlay,
          recordHistory: false,
          recordPlayback: false,
          initialPosition: _pendingRestorePosition,
        ),
      );
      return;
    }

    if (_queue.isNotEmpty && _player.audioSource != null) {
      final shouldResume = resolveAutoPlayBehavior(
        trigger: PlaybackResumeTrigger.statePreservingRestore,
        wasPlaying: _player.playing,
        autoPlayOnLaunchRestore: autoPlayOnRestore,
      );
      unawaited(
        _rebuildPreparedQueue(
          shouldResume: shouldResume,
          initialPosition: _player.position,
          recordHistory: false,
          recordPlayback: false,
        ),
      );
    }
  }

  void clearAuth() {
    _token = null;
    _baseUrl = null;
    _preparedQueueSignature = '';
    _pendingPlayAfterAuth = false;
  }

  void setCacheConfig(CacheService service, int maxBytes) {
    _cacheService = service;
    _maxCacheBytes = maxBytes;
  }

  Future<void> initHistoryStorage(SharedPreferences prefs) async {
    _prefs = prefs;
    final rawHistory = prefs.getStringList(_historyStorageKey) ?? const [];
    final restored = <Track>[];

    for (final item in rawHistory) {
      try {
        final data = jsonDecode(item) as Map<String, dynamic>;
        restored.add(Track.fromJson(data));
      } catch (e) {
        debugPrint('Failed to decode play history item: $e');
      }
    }

    _history
      ..clear()
      ..addAll(restored.take(_maxHistoryLength));

    final rawTrackProgress = prefs.getString(_trackProgressStorageKey);
    if (rawTrackProgress != null && rawTrackProgress.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawTrackProgress) as Map<String, dynamic>;
        _trackResumePositions
          ..clear()
          ..addEntries(
            decoded.entries.map(
              (entry) => MapEntry(entry.key, (entry.value as num).toInt()),
            ),
          );
      } catch (e) {
        debugPrint('Failed to decode track resume positions: $e');
      }
    }

    final rawLyricOffsets = prefs.getString(_lyricOffsetStorageKey);
    if (rawLyricOffsets != null && rawLyricOffsets.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawLyricOffsets) as Map<String, dynamic>;
        _lyricOffsets
          ..clear()
          ..addEntries(
            decoded.entries.map(
              (entry) => MapEntry(entry.key, (entry.value as num).toInt()),
            ),
          );
      } catch (e) {
        debugPrint('Failed to decode lyric offsets: $e');
      }
    }

    final rawEqualizerState = prefs.getString(_equalizerStateStorageKey);
    if (rawEqualizerState != null && rawEqualizerState.isNotEmpty) {
      try {
        _equalizerState = EqualizerStateSnapshot.fromJson(
          jsonDecode(rawEqualizerState) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('Failed to decode equalizer state: $e');
      }
    } else {
      final legacyPresetId = EqualizerPresetProfile.fromId(
        prefs.getString(_equalizerPresetStorageKey),
      ).id;
      _equalizerState = EqualizerStateSnapshot(
        enabled: legacyPresetId != EqualizerPresetId.off.id,
        presetId: legacyPresetId,
        bands: const <EqualizerBandSetting>[],
      );
    }

    await _restoreSession();
    notifyListeners();
  }

  Track? get currentTrack => _queue.isNotEmpty && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  List<Track> get trackQueue => List.unmodifiable(_queue);
  List<Track> get playHistory => List.unmodifiable(_history);
  int get currentIndex => _currentIndex;

  AudioPlayer get player => _player;
  Stream<Duration?> get sleepTimerStream => _sleepTimerController.stream;
  Duration? get sleepTimerRemaining => _sleepRemaining;
  String get equalizerPresetId => _equalizerState.presetId;
  bool get equalizerEnabled => _equalizerState.enabled;
  bool get equalizerReady => _equalizerParameters != null;
  List<EqualizerBandSetting> get equalizerBands =>
      List.unmodifiable(_equalizerState.bands);
  double get equalizerMinDecibels => _equalizerParameters?.minDecibels ?? -12.0;
  double get equalizerMaxDecibels => _equalizerParameters?.maxDecibels ?? 12.0;
  bool get supportsEqualizer => _usesEqualizerPlaybackPipeline;
  List<EqualizerPresetProfile> get equalizerPresets =>
      EqualizerPresetProfile.profiles;

  int lyricOffsetForTrack(String trackId) => _lyricOffsets[trackId] ?? 0;
  String? cachedLyricsForTrack(String trackId) =>
      currentTrack?.id == trackId ? _currentRawLyrics : null;

  void setRemotePreferenceSync(
    Future<void> Function(String key, Object? value)? sync,
  ) {
    _remotePreferenceSync = sync;
  }

  AudioPlayer _buildAudioPlayer() {
    if (_usesEqualizerPlaybackPipeline) {
      return AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer]),
      );
    }
    return AudioPlayer();
  }

  bool get _usesEqualizerPlaybackPipeline => isEqualizerPlaybackPipelineEnabled(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  Future<bool> prepareEqualizer() async {
    if (!supportsEqualizer || _player.audioSource == null) {
      return false;
    }
    if (_equalizerParameters != null && _equalizerState.bands.isNotEmpty) {
      return true;
    }

    try {
      final parameters = await _equalizer.parameters;
      _equalizerParameters = parameters;
      _equalizerState = _equalizerState.copyWith(
        bands: _buildEqualizerBands(parameters),
      );
      await _applyEqualizerStateToPlayer(persist: false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Equalizer initialization failed: $e');
      return false;
    }
  }

  Future<void> setEqualizerEnabled(
    bool enabled, {
    bool syncRemote = true,
  }) async {
    if (enabled &&
        supportsEqualizer &&
        _player.audioSource != null &&
        _equalizerParameters == null) {
      await prepareEqualizer();
    }
    _equalizerState = _equalizerState.copyWith(enabled: enabled);
    notifyListeners();

    if (supportsEqualizer) {
      try {
        await _equalizer.setEnabled(enabled);
        if (enabled) {
          await _applyEqualizerStateToPlayer(persist: false);
        }
      } catch (e) {
        debugPrint('Equalizer enable toggle failed: $e');
      }
    }

    await _persistEqualizerState(syncRemote: syncRemote);
  }

  Future<void> setEqualizerBandGain(
    int bandIndex,
    double gain, {
    bool persist = true,
  }) async {
    if (supportsEqualizer &&
        _player.audioSource != null &&
        _equalizerParameters == null) {
      await prepareEqualizer();
    }

    final parameters = _equalizerParameters;
    final clamped = parameters == null
        ? gain
        : gain.clamp(parameters.minDecibels, parameters.maxDecibels).toDouble();

    _equalizerState = _equalizerState.withBandGain(bandIndex, clamped);
    notifyListeners();

    if (supportsEqualizer) {
      try {
        await _equalizer.setEnabled(true);
        final parameters = _equalizerParameters;
        if (parameters != null) {
          for (final band in parameters.bands) {
            if (band.index == bandIndex) {
              await band.setGain(clamped);
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Equalizer band update failed: $e');
      }
    }

    if (persist) {
      await _persistEqualizerState(syncRemote: true);
    }
  }

  List<EqualizerBandSetting> _buildEqualizerBands(
    AndroidEqualizerParameters parameters,
  ) {
    if (_equalizerState.bands.isEmpty) {
      final bands = parameters.bands
          .map(
            (band) => EqualizerBandSetting(
              index: band.index,
              centerFrequency: band.centerFrequency,
              gain: band.gain,
            ),
          )
          .toList(growable: false);
      if (_equalizerState.presetId != EqualizerPresetId.off.id &&
          _equalizerState.presetId != EqualizerPresetId.custom.id) {
        return EqualizerStateSnapshot.fromPreset(
          presetId: _equalizerState.presetId,
          enabled: _equalizerState.enabled,
          bands: bands,
        ).bands;
      }
      return bands;
    }

    final savedByIndex = {
      for (final band in _equalizerState.bands) band.index: band,
    };
    return parameters.bands
        .map((band) {
          final saved = savedByIndex[band.index];
          return EqualizerBandSetting(
            index: band.index,
            centerFrequency: band.centerFrequency,
            gain: saved?.gain ?? band.gain,
          );
        })
        .toList(growable: false);
  }

  Future<void> loadQueue(
    List<Track> tracks, {
    int startIndex = 0,
    bool restoreTrackPosition = true,
  }) async {
    _queue = tracks;
    _currentIndex = startIndex.clamp(
      0,
      tracks.isNotEmpty ? tracks.length - 1 : 0,
    );
    _preparedQueueSignature = '';
    _activeTrackId = null;
    notifyListeners();
    await _playCurrentTrack(restoreTrackPosition: restoreTrackPosition);
  }

  Future<void> playSingle(
    Track track, {
    bool restoreTrackPosition = true,
  }) async {
    _queue = [track];
    _currentIndex = 0;
    _preparedQueueSignature = '';
    _activeTrackId = null;
    notifyListeners();
    await _playCurrentTrack(restoreTrackPosition: restoreTrackPosition);
  }

  Future<void> playTrackPreservingQueue(
    Track track, {
    bool restoreTrackPosition = true,
  }) async {
    final existingIndex = _queue.indexWhere((item) => item.id == track.id);
    if (existingIndex != -1) {
      _currentIndex = existingIndex;
      notifyListeners();
      await _playCurrentTrack(restoreTrackPosition: restoreTrackPosition);
      return;
    }

    if (_queue.isEmpty) {
      await playSingle(track, restoreTrackPosition: restoreTrackPosition);
      return;
    }

    final insertIndex = (_currentIndex + 1).clamp(0, _queue.length);
    _queue = List<Track>.from(_queue)..insert(insertIndex, track);
    _currentIndex = insertIndex;
    _preparedQueueSignature = '';
    _activeTrackId = null;
    notifyListeners();
    await _playCurrentTrack(restoreTrackPosition: restoreTrackPosition);
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    if (oldIndex < 0 ||
        oldIndex >= _queue.length ||
        newIndex < 0 ||
        newIndex >= _queue.length ||
        oldIndex == newIndex) {
      return;
    }

    final currentTrackId = currentTrack?.id;
    final updatedQueue = List<Track>.from(_queue);
    final item = updatedQueue.removeAt(oldIndex);
    updatedQueue.insert(newIndex, item);

    final movedCurrentIndex = currentTrackId == null
        ? _currentIndex
        : updatedQueue.indexWhere((track) => track.id == currentTrackId);

    final canMoveInPlace =
        _player.audioSource != null && _player.sequence.length == _queue.length;

    if (canMoveInPlace) {
      _suppressedIndexEvents++;
      await _player.moveAudioSource(oldIndex, newIndex);
      _queue = updatedQueue;
      if (movedCurrentIndex >= 0) {
        _currentIndex = movedCurrentIndex;
      }
      _preparedQueueSignature = _queueSignature();
      _pushQueueToAudioService();
      notifyListeners();
      await _persistSession();
      return;
    }

    final currentPosition = _player.position;
    final shouldResume = _player.playing;
    _queue = updatedQueue;
    if (movedCurrentIndex >= 0) {
      _currentIndex = movedCurrentIndex;
    }
    _preparedQueueSignature = '';
    notifyListeners();
    await _rebuildPreparedQueue(
      shouldResume: shouldResume,
      initialPosition: currentPosition,
      recordHistory: false,
      recordPlayback: false,
    );
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _queue.length) {
      return;
    }

    final removingCurrent = index == _currentIndex;
    final currentPosition = _player.position;
    final shouldResume = _player.playing;
    _queue = List<Track>.from(_queue)..removeAt(index);
    if (_queue.isEmpty) {
      _currentIndex = 0;
      _preparedQueueSignature = '';
      _activeTrackId = null;
      notifyListeners();
      queue.add(const <MediaItem>[]);
      await stop();
      return;
    }

    if (index < _currentIndex) {
      _currentIndex -= 1;
    } else if (removingCurrent) {
      _currentIndex = index.clamp(0, _queue.length - 1);
    }

    _preparedQueueSignature = '';
    if (removingCurrent) {
      _activeTrackId = null;
    }
    notifyListeners();
    if (removingCurrent) {
      await _playCurrentTrack(
        autoPlay: shouldResume,
        restoreTrackPosition: false,
        recordHistory: true,
        recordPlayback: true,
      );
    } else {
      await _rebuildPreparedQueue(
        shouldResume: shouldResume,
        initialPosition: currentPosition,
        recordHistory: false,
        recordPlayback: false,
      );
    }
  }

  Future<void> clearQueue() async {
    _queue = [];
    _currentIndex = 0;
    _preparedQueueSignature = '';
    _activeTrackId = null;
    queue.add(const <MediaItem>[]);
    notifyListeners();
    await stop();
  }

  Future<void> setLyricOffset(String trackId, Duration offset) async {
    final milliseconds = offset.inMilliseconds;
    if (milliseconds == 0) {
      _lyricOffsets.remove(trackId);
    } else {
      _lyricOffsets[trackId] = milliseconds;
    }
    if (currentTrack?.id == trackId) {
      _reparseCurrentLyrics();
    }
    notifyListeners();
    await _persistLyricOffsets();
  }

  Future<void> refreshLyricsForTrack(String trackId) async {
    if (currentTrack?.id != trackId) {
      return;
    }
    _lastLyricIndex = -1;
    await _fetchAndParseLyrics(trackId);
  }

  void refreshTrackMetadata(Track updatedTrack) {
    final queueIndex = _queue.indexWhere((item) => item.id == updatedTrack.id);
    if (queueIndex != -1) {
      _queue = List<Track>.from(_queue)..[queueIndex] = updatedTrack;
      _preparedQueueSignature = '';
      _pushQueueToAudioService();
    }

    final historyIndex = _history.indexWhere(
      (item) => item.id == updatedTrack.id,
    );
    if (historyIndex != -1) {
      _history[historyIndex] = updatedTrack;
      unawaited(_persistHistory());
    }

    if (currentTrack?.id == updatedTrack.id) {
      _updateMediaItemWithLyric(
        _lastLyricIndex != -1 && _currentLyrics.isNotEmpty
            ? _currentLyrics[_lastLyricIndex].text
            : null,
      );
    }

    notifyListeners();
  }

  String _queueSignature() {
    final ids = _queue
        .map((track) => '${track.id}:${track.extension}')
        .join('|');
    return '$ids|${_baseUrl ?? ''}|${_token ?? ''}';
  }

  String _systemLyricSubtitle(Track track) {
    final title = track.title.trim();
    final artist = track.artist.trim();
    if (title.isEmpty) {
      return artist;
    }
    if (artist.isEmpty) {
      return title;
    }
    return '$title - $artist';
  }

  MediaItem _mediaItemForTrack(Track track, {String? lyric}) {
    final artUri = (_baseUrl == null || _token == null)
        ? null
        : Uri.tryParse('$_baseUrl/api/tracks/${track.id}/cover?auth=$_token');
    final normalizedLyric = lyric?.trim();
    final hasLyric = normalizedLyric != null && normalizedLyric.isNotEmpty;
    final useSystemLyricMetadata =
        hasLyric && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final systemTitle = useSystemLyricMetadata ? normalizedLyric : track.title;
    final systemArtist = useSystemLyricMetadata
        ? _systemLyricSubtitle(track)
        : track.artist;

    return MediaItem(
      id: track.id,
      title: systemTitle,
      artist: systemArtist,
      album: track.album,
      duration: Duration(seconds: track.duration.toInt()),
      artUri: artUri,
      displayTitle: systemTitle,
      displaySubtitle: useSystemLyricMetadata ? systemArtist : normalizedLyric,
      displayDescription: useSystemLyricMetadata
          ? normalizedLyric
          : _systemLyricSubtitle(track),
      extras: {
        ...?hasLyric
            ? {
                'lyric': normalizedLyric,
                'android.media.metadata.LYRIC': normalizedLyric,
              }
            : null,
        'real_title': track.title,
        'real_artist': track.artist,
        'system_title': systemTitle,
        'system_artist': systemArtist,
        'lyric_mode': useSystemLyricMetadata,
      },
    );
  }

  void _pushQueueToAudioService() {
    queue.add(
      _queue.map((track) => _mediaItemForTrack(track)).toList(growable: false),
    );
  }

  AudioSource _networkAudioSource(Track track, MediaItem item) {
    return AudioSource.uri(
      Uri.parse('$_baseUrl/api/tracks/${track.id}/stream?auth=$_token'),
      headers: {'Authorization': 'Bearer $_token'},
      tag: item,
    );
  }

  Future<AudioSource> _buildAudioSource(
    Track track, {
    required bool preferCachedFile,
  }) async {
    final item = _mediaItemForTrack(track);

    if (preferCachedFile && _cacheService != null) {
      final cacheFile = await _cacheService!.getCachedTrack(
        track.id,
        track.extension,
      );
      if (cacheFile != null && await cacheFile.exists()) {
        return AudioSource.file(cacheFile.path, tag: item);
      }
    }

    if (_baseUrl == null || _token == null) {
      throw StateError('Playback auth is missing.');
    }

    return _networkAudioSource(track, item);
  }

  Future<void> _ensureTrackCaching(Track track) async {
    if (_cacheService == null || _baseUrl == null || _token == null) {
      return;
    }

    try {
      final cachedFile = await _cacheService!.getCachedTrack(
        track.id,
        track.extension,
      );
      if (cachedFile != null && await cachedFile.exists()) {
        return;
      }

      await _cacheService!.cacheTrack(
        track,
        '$_baseUrl/api/tracks/${track.id}/stream?auth=$_token',
        {'Authorization': 'Bearer $_token'},
        maxCacheBytes: _maxCacheBytes,
      );
    } catch (e) {
      debugPrint('Track cache warmup failed: $e');
    }
  }

  Future<void> _ensureQueuePrepared({
    required int initialIndex,
    Duration? initialPosition,
  }) async {
    if (_queue.isEmpty) {
      return;
    }

    final signature = _queueSignature();
    if (_player.audioSource != null && _preparedQueueSignature == signature) {
      return;
    }

    final safeIndex = initialIndex.clamp(0, _queue.length - 1);
    final cachePlan = buildQueueCachedSourcePlan(
      queueLength: _queue.length,
      currentIndex: safeIndex,
    );
    final sources = await Future.wait(
      _queue.asMap().entries.map(
        (entry) => _buildAudioSource(
          entry.value,
          preferCachedFile: cachePlan[entry.key],
        ),
      ),
    );
    _suppressedIndexEvents++;
    await _player.setAudioSources(
      sources,
      initialIndex: safeIndex,
      initialPosition: initialPosition,
      preload: true,
    );
    if (_player.shuffleModeEnabled) {
      await _player.shuffle();
    }
    await _applyEqualizerPresetToPlayer();
    _preparedQueueSignature = signature;
    _activeTrackId = null;
    _currentIndex = _player.currentIndex ?? safeIndex;
    _pushQueueToAudioService();
  }

  Future<void> _seekToQueueIndex(
    int index, {
    Duration position = Duration.zero,
  }) async {
    _suppressedIndexEvents++;
    await _player.seek(position, index: index);
    _currentIndex = index;
  }

  Future<void> _rebuildPreparedQueue({
    required bool shouldResume,
    Duration? initialPosition,
    bool recordHistory = false,
    bool recordPlayback = false,
  }) async {
    if (_queue.isEmpty) {
      return;
    }
    _preparedQueueSignature = '';
    await _playCurrentTrack(
      autoPlay: shouldResume,
      initialPosition: initialPosition,
      restoreTrackPosition: false,
      recordHistory: recordHistory,
      recordPlayback: recordPlayback,
    );
  }

  void _addToHistory(Track track) {
    _history.removeWhere((item) => item.id == track.id);
    _history.insert(0, track);
    if (_history.length > _maxHistoryLength) {
      _history.removeRange(_maxHistoryLength, _history.length);
    }
    unawaited(_persistHistory());
  }

  Future<void> _persistHistory() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    final encoded = _history
        .map((track) => jsonEncode(track.toJson()))
        .toList(growable: false);
    await prefs.setStringList(_historyStorageKey, encoded);
  }

  Future<void> _persistTrackProgress() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    await prefs.setString(
      _trackProgressStorageKey,
      jsonEncode(_trackResumePositions),
    );
  }

  Future<void> _persistLyricOffsets() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setString(_lyricOffsetStorageKey, jsonEncode(_lyricOffsets));
    await _syncRemotePreference('player_lyric_offsets', _lyricOffsets);
  }

  Future<void> _persistEqualizerState({required bool syncRemote}) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setString(_equalizerPresetStorageKey, _equalizerState.presetId);
    await prefs.setString(
      _equalizerStateStorageKey,
      jsonEncode(_equalizerState.toJson()),
    );
    if (syncRemote) {
      await _syncRemotePreference(
        'player_equalizer_preset',
        _equalizerState.presetId,
      );
      await _syncRemotePreference(
        'player_equalizer_state',
        _equalizerState.toJson(),
      );
    }
  }

  Duration _savedTrackPosition(Track track) {
    final savedMs = _trackResumePositions[track.id] ?? 0;
    if (savedMs < 5000) {
      return Duration.zero;
    }
    return Duration(milliseconds: savedMs);
  }

  void _saveTrackProgress({Track? track, Duration? position}) {
    final targetTrack = track ?? currentTrack;
    if (targetTrack == null) {
      return;
    }

    final durationMs = (targetTrack.duration * 1000).round();
    final positionMs = (position ?? _player.position).inMilliseconds;

    _trackResumePositions.remove(targetTrack.id);
    if (durationMs > 0 && positionMs >= durationMs - 3000) {
      unawaited(_persistTrackProgress());
      return;
    }
    if (positionMs >= 5000) {
      _trackResumePositions[targetTrack.id] = positionMs;
    }
    while (_trackResumePositions.length > _maxTrackResumeEntries) {
      _trackResumePositions.remove(_trackResumePositions.keys.first);
    }
    unawaited(_persistTrackProgress());
  }

  void _clearTrackProgress(String? trackId) {
    if (trackId == null) {
      return;
    }
    if (_trackResumePositions.remove(trackId) != null) {
      unawaited(_persistTrackProgress());
    }
  }

  Future<void> _restoreSession() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    final raw = prefs.getString(_sessionStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final queueJson = data['queue'] as List<dynamic>? ?? const [];
      final restoredQueue = queueJson
          .map((item) => Track.fromJson(item as Map<String, dynamic>))
          .toList();
      if (restoredQueue.isEmpty) {
        return;
      }

      _queue = restoredQueue;
      _currentIndex = ((data['currentIndex'] as num?)?.toInt() ?? 0).clamp(
        0,
        restoredQueue.length - 1,
      );
      _pendingRestorePosition = Duration(
        milliseconds: (data['positionMs'] as num?)?.toInt() ?? 0,
      );
      _pendingRestoreShouldResume = data['shouldResume'] as bool? ?? false;
      final shuffleEnabled = data['shuffleEnabled'] as bool? ?? false;
      final loopModeValue = data['loopMode'] as String? ?? 'off';
      final loopMode = switch (loopModeValue) {
        'one' => LoopMode.one,
        'all' => LoopMode.all,
        _ => LoopMode.off,
      };
      await _player.setShuffleModeEnabled(shuffleEnabled);
      await _player.setLoopMode(loopMode);
      await _player.setSpeed(1.0);
      _preparedQueueSignature = '';
    } catch (e) {
      debugPrint('Failed to restore playback session: $e');
    }
  }

  Future<void> _persistSession() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    if (_queue.isEmpty) {
      await prefs.remove(_sessionStorageKey);
      return;
    }

    final payload = {
      'queue': _queue.map((track) => track.toJson()).toList(growable: false),
      'currentIndex': _currentIndex,
      'positionMs': _player.position.inMilliseconds,
      'shouldResume': _player.playing,
      'shuffleEnabled': _player.shuffleModeEnabled,
      'loopMode': switch (_player.loopMode) {
        LoopMode.one => 'one',
        LoopMode.all => 'all',
        LoopMode.off => 'off',
      },
    };
    await prefs.setString(_sessionStorageKey, jsonEncode(payload));
    await _syncRemotePreference('player_session', payload);
  }

  Future<void> _syncRemotePreference(String key, Object? value) async {
    final sync = _remotePreferenceSync;
    if (sync == null) {
      return;
    }
    try {
      await sync(key, value);
    } catch (e) {
      debugPrint('Remote preference sync failed for $key: $e');
    }
  }

  Future<void> applyRemotePreferences(
    Map<String, dynamic> data, {
    bool autoPlayOnRestore = false,
  }) async {
    final remoteOffsets = data['player_lyric_offsets'];
    if (remoteOffsets is Map<String, dynamic>) {
      _lyricOffsets
        ..clear()
        ..addEntries(
          remoteOffsets.entries.map(
            (entry) => MapEntry(entry.key, (entry.value as num).toInt()),
          ),
        );
      await _persistLyricOffsets();
    }

    final remoteSession = data['player_session'];
    if (remoteSession is Map<String, dynamic> && _queue.isEmpty) {
      final prefs = _prefs;
      if (prefs != null) {
        await prefs.setString(_sessionStorageKey, jsonEncode(remoteSession));
        await _restoreSession();
        if (_queue.isNotEmpty && _token != null && _baseUrl != null) {
          await _playCurrentTrack(
            autoPlay: resolveAutoPlayBehavior(
              trigger: PlaybackResumeTrigger.launchRestore,
              wasPlaying: _pendingRestoreShouldResume,
              autoPlayOnLaunchRestore: autoPlayOnRestore,
            ),
            recordHistory: false,
            recordPlayback: false,
            initialPosition: _pendingRestorePosition,
          );
        }
      }
    }

    final remoteEqualizerState = data['player_equalizer_state'];
    if (remoteEqualizerState is Map<String, dynamic>) {
      _equalizerState = EqualizerStateSnapshot.fromJson(remoteEqualizerState);
      if (_player.audioSource != null) {
        await prepareEqualizer();
      }
      await _applyEqualizerStateToPlayer(persist: false);
    } else {
      final remotePresetId = data['player_equalizer_preset'];
      if (remotePresetId is String && remotePresetId.isNotEmpty) {
        await setEqualizerPreset(remotePresetId, syncRemote: false);
      }
    }

    notifyListeners();
  }

  Future<void> setEqualizerPreset(
    String presetId, {
    bool syncRemote = true,
  }) async {
    final profile = EqualizerPresetProfile.fromId(presetId);
    if (_player.audioSource != null) {
      await prepareEqualizer();
    }

    final baseBands = _equalizerState.bands;
    _equalizerState = EqualizerStateSnapshot.fromPreset(
      presetId: profile.id,
      enabled: profile.id != EqualizerPresetId.off.id,
      bands: baseBands,
    );
    notifyListeners();

    await _applyEqualizerStateToPlayer(persist: syncRemote);
  }

  Future<void> _applyEqualizerStateToPlayer({required bool persist}) async {
    if (!supportsEqualizer) {
      if (persist) {
        await _persistEqualizerState(syncRemote: true);
      }
      return;
    }

    if (_player.audioSource != null &&
        (_equalizerParameters == null || _equalizerState.bands.isEmpty)) {
      await prepareEqualizer();
    }

    try {
      final shouldEnable =
          _equalizerState.enabled &&
          _equalizerState.presetId != EqualizerPresetId.off.id;
      await _equalizer.setEnabled(shouldEnable);
      if (shouldEnable && _equalizerParameters != null) {
        final gainsByIndex = {
          for (final band in _equalizerState.bands) band.index: band.gain,
        };
        for (final band in _equalizerParameters!.bands) {
          final gain = gainsByIndex[band.index];
          if (gain != null) {
            await band.setGain(
              gain
                  .clamp(
                    _equalizerParameters!.minDecibels,
                    _equalizerParameters!.maxDecibels,
                  )
                  .toDouble(),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Equalizer state apply failed: $e');
    }

    if (persist) {
      await _persistEqualizerState(syncRemote: true);
    } else {
      final prefs = _prefs;
      if (prefs != null) {
        await prefs.setString(
          _equalizerStateStorageKey,
          jsonEncode(_equalizerState.toJson()),
        );
        await prefs.setString(
          _equalizerPresetStorageKey,
          _equalizerState.presetId,
        );
      }
    }
    notifyListeners();
  }

  Future<void> _applyEqualizerPresetToPlayer() async {
    await _applyEqualizerStateToPlayer(persist: false);
  }

  Future<void> _playCurrentTrack({
    bool autoPlay = true,
    bool recordHistory = true,
    bool recordPlayback = true,
    Duration? initialPosition,
    bool restoreTrackPosition = false,
  }) async {
    final track = currentTrack;
    if (track == null) return;

    if (_token == null || _baseUrl == null) {
      debugPrint(
        'Warning: Attempted to play track "${track.title}" without auth. Will retry when auth arrives.',
      );
      _pendingPlayAfterAuth = true;
      return;
    }

    try {
      final resumePosition =
          initialPosition ??
          (restoreTrackPosition ? _savedTrackPosition(track) : Duration.zero);
      if (_player.audioSource == null ||
          _preparedQueueSignature != _queueSignature()) {
        await _ensureQueuePrepared(
          initialIndex: _currentIndex,
          initialPosition: resumePosition,
        );
      } else {
        final shouldSeek =
            _player.currentIndex != _currentIndex ||
            (_player.position - resumePosition).abs() >
                const Duration(milliseconds: 250);
        if (shouldSeek) {
          await _seekToQueueIndex(_currentIndex, position: resumePosition);
        }
      }

      await _syncActiveTrackState(
        force: true,
        recordHistory: recordHistory,
        recordPlayback: recordPlayback,
      );

      if (autoPlay) {
        if (!_player.playing) {
          await _player.play();
        }
      } else {
        await _player.pause();
      }
      _pendingRestorePosition = null;
      _pendingRestoreShouldResume = false;
      await _persistSession();
    } catch (e) {
      debugPrint('SetAudioSource error: $e');
    }
  }

  @override
  Future<void> play() async {
    if (_player.audioSource == null && currentTrack != null) {
      await _playCurrentTrack(
        autoPlay: true,
        recordHistory: false,
        recordPlayback: false,
        restoreTrackPosition: true,
      );
      return;
    }
    await _player.play();
    await _persistSession();
  }

  Future<void> _handlePlaybackCompleted() async {
    try {
      if (_queue.isEmpty) {
        return;
      }

      _clearTrackProgress(currentTrack?.id);
      final action = resolvePlaybackCompletionAction(
        nextIndex: _player.nextIndex,
        isSingleTrackLoop: _player.loopMode == LoopMode.one,
      );

      switch (action.kind) {
        case PlaybackCompletionKind.restartCurrent:
          await _seekToQueueIndex(_currentIndex, position: Duration.zero);
          await _syncActiveTrackState(
            force: true,
            recordHistory: false,
            recordPlayback: false,
          );
          await _player.play();
          return;
        case PlaybackCompletionKind.playNext:
          _currentIndex = action.nextIndex!;
          notifyListeners();
          await _playCurrentTrack(autoPlay: true, restoreTrackPosition: false);
          return;
        case PlaybackCompletionKind.pauseCurrent:
          await _seekToQueueIndex(_currentIndex, position: Duration.zero);
          await _player.pause();
      }
      await _persistSession();
    } finally {
      _isHandlingCompletion = false;
    }
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _saveTrackProgress();
    await _persistSession();
  }

  @override
  Future<void> stop() async {
    _currentLyrics = [];
    _currentRawLyrics = null;
    _lastLyricIndex = -1;
    _saveTrackProgress();
    await _player.stop();
    await _persistSession();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _saveTrackProgress(position: position);
    await _persistSession();
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    final nextIndex = _player.nextIndex;
    if (nextIndex == null) {
      _clearTrackProgress(currentTrack?.id);
      await _seekToQueueIndex(_currentIndex, position: Duration.zero);
      await _player.pause();
      await _persistSession();
      return;
    }

    _currentIndex = nextIndex;
    notifyListeners();
    await _playCurrentTrack(
      autoPlay: resolveAutoPlayBehavior(
        trigger: PlaybackResumeTrigger.manualSkip,
        wasPlaying: _player.playing,
        autoPlayOnLaunchRestore: false,
      ),
      restoreTrackPosition: false,
    );
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    final previousIndex = _player.previousIndex;
    if (previousIndex == null) {
      await _player.seek(Duration.zero);
      return;
    }

    _currentIndex = previousIndex;
    notifyListeners();
    await _playCurrentTrack(
      autoPlay: resolveAutoPlayBehavior(
        trigger: PlaybackResumeTrigger.manualSkip,
        wasPlaying: _player.playing,
        autoPlayOnLaunchRestore: false,
      ),
      restoreTrackPosition: false,
    );
  }

  Future<void> _syncExclusivePlaybackModes() async {
    if (_isSyncingExclusiveModes) {
      return;
    }

    final shuffleEnabled = _player.shuffleModeEnabled;
    final loopMode = _player.loopMode;
    if (!shuffleEnabled || loopMode != LoopMode.one) {
      return;
    }

    _isSyncingExclusiveModes = true;
    try {
      if (_lastExclusiveMode == _ExclusivePlaybackMode.singleLoop) {
        await _player.setShuffleModeEnabled(false);
      } else {
        await _player.setLoopMode(LoopMode.off);
      }
    } finally {
      _isSyncingExclusiveModes = false;
    }
  }

  Future<void> toggleShuffle() async {
    final enabled = !_player.shuffleModeEnabled;
    if (enabled) {
      _lastExclusiveMode = _ExclusivePlaybackMode.shuffle;
    }
    if (enabled && _player.loopMode == LoopMode.one) {
      await _player.setLoopMode(LoopMode.off);
    }

    await _player.setShuffleModeEnabled(enabled);
    if (enabled) {
      await _player.shuffle();
    }

    _currentIndex = _player.currentIndex ?? _currentIndex;
    notifyListeners();
    await _persistSession();
  }

  Future<void> toggleLoopMode() async {
    switch (_player.loopMode) {
      case LoopMode.off:
        _lastExclusiveMode = _ExclusivePlaybackMode.singleLoop;
        if (_player.shuffleModeEnabled) {
          await _player.setShuffleModeEnabled(false);
        }
        await _player.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await _player.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await _player.setLoopMode(LoopMode.off);
        break;
    }

    notifyListeners();
    await _persistSession();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    if (enabled) {
      _lastExclusiveMode = _ExclusivePlaybackMode.shuffle;
    }
    if (enabled && _player.loopMode == LoopMode.one) {
      await _player.setLoopMode(LoopMode.off);
    }

    await _player.setShuffleModeEnabled(enabled);
    if (enabled) {
      await _player.shuffle();
    }

    _currentIndex = _player.currentIndex ?? _currentIndex;
    notifyListeners();
    await _persistSession();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _ => LoopMode.off,
    };

    if (loopMode == LoopMode.one) {
      _lastExclusiveMode = _ExclusivePlaybackMode.singleLoop;
    }
    if (loopMode == LoopMode.one && _player.shuffleModeEnabled) {
      await _player.setShuffleModeEnabled(false);
    }

    await _player.setLoopMode(loopMode);
    notifyListeners();
    await _persistSession();
  }

  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepRemaining = duration;
    _sleepTimerController.add(_sleepRemaining);
    notifyListeners();

    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepRemaining;
      if (remaining == null) {
        timer.cancel();
        return;
      }

      final next = remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _sleepRemaining = Duration.zero;
      } else {
        _sleepRemaining = next;
      }
      _sleepTimerController.add(_sleepRemaining);
      notifyListeners();
    });

    _sleepTimer = Timer(duration, () async {
      cancelSleepTimer();
      await pause();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepTimer = null;
    _sleepTicker = null;
    _sleepRemaining = null;
    _sleepTimerController.add(null);
    notifyListeners();
  }

  Future<void> _handleCurrentIndexChanged(int index) async {
    if (index < 0 || index >= _queue.length) {
      return;
    }

    final previousTrack = currentTrack;
    final nextTrack = _queue[index];
    if (previousTrack != null && previousTrack.id != nextTrack.id) {
      _saveTrackProgress(track: previousTrack);
    }

    _currentIndex = index;
    await _syncActiveTrackState(
      force: true,
      recordHistory: true,
      recordPlayback: true,
    );
    await _persistSession();
  }

  Future<void> _syncActiveTrackState({
    bool force = false,
    bool recordHistory = true,
    bool recordPlayback = true,
  }) async {
    final track = currentTrack;
    if (track == null) {
      return;
    }

    if (!force && _activeTrackId == track.id) {
      return;
    }

    _activeTrackId = track.id;
    _currentLyrics = [];
    _currentRawLyrics = null;
    _lastLyricIndex = -1;
    mediaItem.add(_mediaItemForTrack(track));
    unawaited(_fetchAndParseLyrics(track.id));
    if (recordHistory) {
      _addToHistory(track);
    }
    if (recordPlayback) {
      unawaited(_recordPlayback(track.id));
    }
    unawaited(_ensureTrackCaching(track));
    notifyListeners();
  }

  Future<String?> getLyrics(String trackId) async {
    if (_baseUrl == null || _token == null) return null;
    try {
      final response = await _networkDio.get(
        '$_baseUrl/api/tracks/$trackId/lyrics',
        options: _authorizedOptions(),
      );
      if (response.data != null && response.data['success'] == true) {
        return response.data['lyrics'] as String?;
      }
    } catch (e) {
      debugPrint('Lyrics fetch error: $e');
    }
    return null;
  }

  Future<void> _fetchAndParseLyrics(String trackId, {int attempt = 0}) async {
    final lyrics = await getLyrics(trackId);
    if (currentTrack?.id != trackId) {
      return;
    }

    final hasLyrics = lyrics != null && lyrics.trim().isNotEmpty;
    if (hasLyrics) {
      _currentRawLyrics = lyrics;
      _currentLyrics = _parseLrc(
        lyrics,
        offset: Duration(milliseconds: lyricOffsetForTrack(trackId)),
      );
    } else {
      _currentRawLyrics = null;
      _currentLyrics = [];
      _lastLyricIndex = -1;
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        if (currentTrack?.id == trackId) {
          await _fetchAndParseLyrics(trackId, attempt: attempt + 1);
        }
        return;
      }
    }
    _updateLyricInMetadata(_player.position);
    notifyListeners();
  }

  void _updateMediaItemWithLyric(String? lyric) {
    final track = currentTrack;
    if (track == null) return;
    mediaItem.add(_mediaItemForTrack(track, lyric: lyric));
  }

  List<_LyricLine> _parseLrc(String lrc, {Duration offset = Duration.zero}) {
    final lines = <_LyricLine>[];
    final reg = RegExp(r'\[(\d+):(\d+\.?\d*)\](.*)');
    for (final line in lrc.split('\n')) {
      final match = reg.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();
        if (text.isNotEmpty) {
          final computed = Duration(
            milliseconds: (min * 60 * 1000 + sec * 1000).toInt(),
          );
          final shifted = computed + offset;
          lines.add(
            _LyricLine(
              time: shifted < Duration.zero ? Duration.zero : shifted,
              text: text,
            ),
          );
        }
      } else if (line.trim().isNotEmpty && !line.startsWith('[')) {
        lines.add(_LyricLine(time: Duration.zero, text: line.trim()));
      }
    }
    return lines;
  }

  void _reparseCurrentLyrics() {
    final trackId = currentTrack?.id;
    final rawLyrics = _currentRawLyrics;
    if (trackId == null || rawLyrics == null) {
      return;
    }
    _currentLyrics = _parseLrc(
      rawLyrics,
      offset: Duration(milliseconds: lyricOffsetForTrack(trackId)),
    );
    _lastLyricIndex = -1;
    _updateLyricInMetadata(_player.position);
  }

  void _updateLyricInMetadata(Duration pos) {
    final item = mediaItem.value;
    if (item == null) return;

    if (_currentLyrics.isEmpty) {
      final track = currentTrack;
      if (track != null &&
          (item.title != track.title || item.artist != track.artist)) {
        _updateMediaItemWithLyric(null);
      }
      return;
    }

    int index = -1;
    for (int i = 0; i < _currentLyrics.length; i++) {
      if (pos >= _currentLyrics[i].time) {
        index = i;
      } else {
        break;
      }
    }

    if (index != _lastLyricIndex) {
      _lastLyricIndex = index;
      final lyricText = index != -1 ? _currentLyrics[index].text : null;
      _updateMediaItemWithLyric(lyricText);
    }
  }

  Future<void> _recordPlayback(String trackId) async {
    if (_baseUrl == null || _token == null) return;
    try {
      await _networkDio.post(
        '$_baseUrl/api/tracks/$trackId/play',
        options: _authorizedOptions(),
      );
    } catch (e) {
      debugPrint('Error recording playback: $e');
    }
  }

  Options _authorizedOptions() {
    return Options(headers: {'Authorization': 'Bearer $_token'});
  }

  void _broadcastState(dynamic _) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.setShuffleMode,
          MediaAction.setRepeatMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex ?? _currentIndex,
        shuffleMode: _player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: {
          LoopMode.off: AudioServiceRepeatMode.none,
          LoopMode.one: AudioServiceRepeatMode.one,
          LoopMode.all: AudioServiceRepeatMode.all,
        }[_player.loopMode]!,
      ),
    );
  }

  @override
  Future<void> onTaskRemoved() => stop();
}

final playerHandlerProvider = ChangeNotifierProvider<MusicPlayerHandler>(
  (ref) => throw UnimplementedError('Must override in main.dart'),
);

enum _ExclusivePlaybackMode { shuffle, singleLoop }

class _LyricLine {
  final Duration time;
  final String text;

  _LyricLine({required this.time, required this.text});
}
