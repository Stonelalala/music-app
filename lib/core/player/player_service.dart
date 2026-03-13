import 'dart:async';
import 'dart:io';
import 'dart:math';
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

class MusicPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler, ChangeNotifier {
  static const _historyStorageKey = 'play_history_tracks';
  static const _sessionStorageKey = 'player_session_state';
  static const _maxHistoryLength = 100;

  final AudioPlayer _player = AudioPlayer();
  List<Track> _queue = [];
  final List<Track> _history = [];
  List<int> _playOrder = [];
  int _orderCursor = 0;
  int _currentIndex = 0;
  String? _token;
  String? _baseUrl;
  CacheService? _cacheService;
  int? _maxCacheBytes;
  SharedPreferences? _prefs;
  bool _pendingPlayAfterAuth = false;
  bool _isSyncingExclusiveModes = false;
  _ExclusivePlaybackMode? _lastExclusiveMode;
  List<_LyricLine> _currentLyrics = [];
  int _lastLyricIndex = -1;
  Duration? _pendingRestorePosition;
  bool _pendingRestoreShouldResume = false;
  Timer? _sleepTimer;
  Timer? _sleepTicker;
  Duration? _sleepRemaining;
  int _lastPersistedSecond = -1;
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
        skipToNext();
      }
    });

    _player.positionStream.listen(_updateLyricInMetadata);
    _player.positionStream.listen((position) {
      final wholeSecond = position.inSeconds;
      if (wholeSecond >= 0 && wholeSecond != _lastPersistedSecond) {
        _lastPersistedSecond = wholeSecond;
        if (wholeSecond == 0 || wholeSecond % 5 == 0) {
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

  void setAuth(String token, String baseUrl) {
    debugPrint('Setting player auth: $baseUrl');
    _token = token;
    _baseUrl = baseUrl;

    if (_pendingPlayAfterAuth) {
      debugPrint('Auth received, retrying pending playback...');
      _pendingPlayAfterAuth = false;
      _playCurrentTrack();
    }

    if (_queue.isNotEmpty && (_pendingRestorePosition != null || _player.audioSource == null)) {
      unawaited(
        _playCurrentTrack(
          autoPlay: _pendingRestoreShouldResume,
          recordHistory: false,
          recordPlayback: false,
          initialPosition: _pendingRestorePosition,
        ),
      );
    }
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

  Future<void> loadQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue = tracks;
    _currentIndex = startIndex.clamp(0, tracks.isNotEmpty ? tracks.length - 1 : 0);
    _rebuildPlayOrder(startIndex: _currentIndex);
    notifyListeners();
    await _playCurrentTrack();
  }

  Future<void> playSingle(Track track) async {
    _queue = [track];
    _currentIndex = 0;
    _rebuildPlayOrder(startIndex: 0);
    notifyListeners();
    await _playCurrentTrack();
  }

  Future<void> playTrackPreservingQueue(Track track) async {
    final existingIndex = _queue.indexWhere((item) => item.id == track.id);
    if (existingIndex != -1) {
      _currentIndex = existingIndex;
      _rebuildPlayOrder(startIndex: _currentIndex);
      notifyListeners();
      await _playCurrentTrack();
      return;
    }

    if (_queue.isEmpty) {
      await playSingle(track);
      return;
    }

    final insertIndex = (_currentIndex + 1).clamp(0, _queue.length);
    _queue = List<Track>.from(_queue)..insert(insertIndex, track);
    _currentIndex = insertIndex;
    _rebuildPlayOrder(startIndex: _currentIndex);
    notifyListeners();
    await _playCurrentTrack();
  }

  void refreshTrackMetadata(Track updatedTrack) {
    final queueIndex = _queue.indexWhere((item) => item.id == updatedTrack.id);
    if (queueIndex != -1) {
      _queue = List<Track>.from(_queue)..[queueIndex] = updatedTrack;
    }

    final historyIndex = _history.indexWhere((item) => item.id == updatedTrack.id);
    if (historyIndex != -1) {
      _history[historyIndex] = updatedTrack;
      unawaited(_persistHistory());
    }

    if (currentTrack?.id == updatedTrack.id) {
      _updateMediaItemWithLyric(
        _lastLyricIndex != -1 && _currentLyrics.isNotEmpty
            ? _currentLyrics[_lastLyricIndex].text
            : updatedTrack.artist,
      );
    }

    notifyListeners();
  }

  void _rebuildPlayOrder({required int startIndex}) {
    _playOrder = List<int>.generate(_queue.length, (i) => i);
    if (_playOrder.isEmpty) {
      _orderCursor = 0;
      return;
    }

    if (_player.shuffleModeEnabled) {
      _playOrder.shuffle(Random());
      final currentPos = _playOrder.indexOf(startIndex);
      if (currentPos > 0) {
        final current = _playOrder.removeAt(currentPos);
        _playOrder.insert(0, current);
      }
      _orderCursor = 0;
    } else {
      _orderCursor = startIndex.clamp(0, _playOrder.length - 1);
    }
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
      _currentIndex = ((data['currentIndex'] as num?)?.toInt() ?? 0)
          .clamp(0, restoredQueue.length - 1);
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
      _rebuildPlayOrder(startIndex: _currentIndex);
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
  }

  Future<void> _playCurrentTrack({
    bool autoPlay = true,
    bool recordHistory = true,
    bool recordPlayback = true,
    Duration? initialPosition,
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

    final item = MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: Duration(seconds: track.duration.toInt()),
      artUri: Uri.parse('$_baseUrl/api/tracks/${track.id}/cover?auth=$_token'),
    );
    mediaItem.add(item);
    _currentLyrics = [];
    _lastLyricIndex = -1;
    unawaited(_fetchAndParseLyrics(track.id));

    try {
      final networkUri = Uri.parse(
        '$_baseUrl/api/tracks/${track.id}/stream?auth=$_token',
      );
      final headers = {'Authorization': 'Bearer $_token'};

      File? cacheFile;
      if (_cacheService != null) {
        cacheFile = await _cacheService!.getCachedTrack(track.id, track.extension);
      }

      if (cacheFile != null && await cacheFile.exists()) {
        debugPrint('Playing from cache: ${track.title}');
        await _player.setAudioSource(AudioSource.file(cacheFile.path, tag: item));
      } else {
        debugPrint('Playing from network: ${track.title}');
        await _player.setAudioSource(
          AudioSource.uri(networkUri, headers: headers, tag: item),
        );

        if (_cacheService != null) {
          _cacheService!.cacheTrack(
            track,
            networkUri.toString(),
            headers,
            maxCacheBytes: _maxCacheBytes,
          );
        }
      }

      if (initialPosition != null && initialPosition > Duration.zero) {
        await _player.seek(initialPosition);
      }

      if (recordHistory) {
        _addToHistory(track);
      }
      if (recordPlayback) {
        unawaited(_recordPlayback(track.id));
      }
      notifyListeners();
      if (autoPlay) {
        await _player.play();
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
    await _player.play();
    await _persistSession();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    await _persistSession();
  }

  @override
  Future<void> stop() async {
    _currentLyrics = [];
    _lastLyricIndex = -1;
    await _player.stop();
    await _persistSession();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    await _persistSession();
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    if (_player.shuffleModeEnabled) {
      if (_orderCursor < _playOrder.length - 1) {
        _orderCursor++;
      } else if (_player.loopMode == LoopMode.all) {
        _rebuildPlayOrder(startIndex: _currentIndex);
        _orderCursor = _playOrder.length > 1 ? 1 : 0;
      } else {
        await _player.seek(Duration.zero);
        await _player.stop();
        return;
      }

      _currentIndex = _playOrder[_orderCursor];
      notifyListeners();
      await _playCurrentTrack();
      return;
    }

    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      notifyListeners();
      await _playCurrentTrack();
    } else if (_player.loopMode == LoopMode.all) {
      _currentIndex = 0;
      notifyListeners();
      await _playCurrentTrack();
    } else {
      await _player.seek(Duration.zero);
      await _player.stop();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_player.shuffleModeEnabled && _playOrder.isNotEmpty) {
      if (_orderCursor > 0) {
        _orderCursor--;
      } else if (_player.loopMode == LoopMode.all) {
        _orderCursor = _playOrder.length - 1;
      } else {
        await _player.seek(Duration.zero);
        return;
      }

      _currentIndex = _playOrder[_orderCursor];
      notifyListeners();
      await _playCurrentTrack();
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      notifyListeners();
      await _playCurrentTrack();
    } else if (_player.loopMode == LoopMode.all && _queue.isNotEmpty) {
      _currentIndex = _queue.length - 1;
      notifyListeners();
      await _playCurrentTrack();
    } else {
      await _player.seek(Duration.zero);
    }
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

    _rebuildPlayOrder(startIndex: _currentIndex);
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

    _rebuildPlayOrder(startIndex: _currentIndex);
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

    _rebuildPlayOrder(startIndex: _currentIndex);
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
    _rebuildPlayOrder(startIndex: _currentIndex);
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

  Future<String?> getLyrics(String trackId) async {
    if (_baseUrl == null || _token == null) return null;
    try {
      final url = '$_baseUrl/api/tracks/$trackId/lyrics?auth=$_token';
      final response = await Dio().get(url);
      if (response.data != null && response.data['success'] == true) {
        return response.data['lyrics'] as String?;
      }
    } catch (e) {
      debugPrint('Lyrics fetch error: $e');
    }
    return null;
  }

  Future<void> _fetchAndParseLyrics(String trackId) async {
    final lyrics = await getLyrics(trackId);
    if (lyrics != null) {
      _currentLyrics = _parseLrc(lyrics);
      _updateLyricInMetadata(_player.position);
    }
  }

  void _updateLyricInMetadata(Duration pos) {
    final item = mediaItem.value;
    if (item == null) return;

    if (_currentLyrics.isEmpty) {
      if (item.displaySubtitle != item.artist) {
        _updateMediaItemWithLyric(item.artist);
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
      final lyricText = index != -1 ? _currentLyrics[index].text : item.artist;
      _updateMediaItemWithLyric(lyricText);
    }
  }

  void _updateMediaItemWithLyric(String? lyric) {
    final item = mediaItem.value;
    final track = currentTrack;
    if (item == null || track == null) return;

    final displayArtist = lyric ?? track.artist;
    if (item.artist == displayArtist && item.displaySubtitle == lyric) {
      return;
    }

    mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: displayArtist,
        album: track.album,
        duration: Duration(seconds: track.duration.toInt()),
        artUri: item.artUri,
        displayTitle: track.title,
        displaySubtitle: lyric,
        displayDescription: lyric,
        extras: {
          'lyric': lyric,
          'android.media.metadata.LYRIC': lyric,
          'real_artist': track.artist,
        },
      ),
    );
  }

  List<_LyricLine> _parseLrc(String lrc) {
    final lines = <_LyricLine>[];
    final reg = RegExp(r'\[(\d+):(\d+\.?\d*)\](.*)');
    for (final line in lrc.split('\n')) {
      final match = reg.firstMatch(line);
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = double.parse(match.group(2)!);
        final text = match.group(3)!.trim();
        if (text.isNotEmpty) {
          lines.add(
            _LyricLine(
              time: Duration(
                milliseconds: (min * 60 * 1000 + sec * 1000).toInt(),
              ),
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

  Future<void> _recordPlayback(String trackId) async {
    if (_baseUrl == null || _token == null) return;
    try {
      await Dio().post(
        '$_baseUrl/api/tracks/$trackId/play',
        options: Options(headers: {'Authorization': 'Bearer $_token'}),
      );
    } catch (e) {
      debugPrint('Error recording playback: $e');
    }
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
        queueIndex: _currentIndex,
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
