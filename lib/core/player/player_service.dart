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
    notifyListeners();
  }

  Track? get currentTrack => _queue.isNotEmpty && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  List<Track> get trackQueue => List.unmodifiable(_queue);
  List<Track> get playHistory => List.unmodifiable(_history);
  int get currentIndex => _currentIndex;

  AudioPlayer get player => _player;

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
      final currentItem = mediaItem.value;
      if (currentItem != null) {
        mediaItem.add(
          currentItem.copyWith(
            title: updatedTrack.title,
            artist: updatedTrack.artist,
            album: updatedTrack.album,
            duration: Duration(seconds: updatedTrack.duration.toInt()),
          ),
        );
      }
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

  Future<void> _playCurrentTrack() async {
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

      _addToHistory(track);
      notifyListeners();
      await _player.play();
    } catch (e) {
      debugPrint('SetAudioSource error: $e');
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

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
