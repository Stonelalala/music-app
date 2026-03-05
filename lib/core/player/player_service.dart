import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

import '../../shared/models/track.dart';
import 'cache_service.dart';

class MusicPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler, ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  List<Track> _queue = [];
  int _currentIndex = 0;
  String? _token;
  String? _baseUrl;
  CacheService? _cacheService;
  int? _maxCacheBytes;
  bool _pendingPlayAfterAuth = false;

  MusicPlayerHandler() {
    _initAudioSession();
    _player.playbackEventStream.listen(_broadcastState);
    _player.shuffleModeEnabledStream.listen((_) => _broadcastState(null));
    _player.loopModeStream.listen((_) => _broadcastState(null));
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
    
    // 如果有等待认证的播放任务，现在执行
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

  Track? get currentTrack => _queue.isNotEmpty && _currentIndex < _queue.length
      ? _queue[_currentIndex]
      : null;

  List<Track> get trackQueue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;

  AudioPlayer get player => _player;

  /// 加载队列并播放指定索引
  Future<void> loadQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue = tracks;
    _currentIndex = startIndex;
    notifyListeners();
    await _playCurrentTrack();
  }

  /// 播放单首曲目（替换队列）
  Future<void> playSingle(Track track) async {
    _queue = [track];
    _currentIndex = 0;
    notifyListeners();
    await _playCurrentTrack();
  }

  Future<void> _playCurrentTrack() async {
    final track = currentTrack;
    if (track == null) return;
    
    // 关键修正：如果此时还没有认证信息，标记为待处理
    if (_token == null || _baseUrl == null) {
      debugPrint('Warning: Attempted to play track "${track.title}" without auth. Will retry when auth arrives.');
      _pendingPlayAfterAuth = true;
      return; 
    }

      // 先推送到系统媒介控制器，让 UI/通知栏立刻显示
    final item = MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: Duration(seconds: track.duration.toInt()),
      artUri: Uri.parse(
        '$_baseUrl/api/tracks/${track.id}/cover?auth=$_token',
      ),
    );
    mediaItem.add(item);

    try {
      final networkUri = Uri.parse(
        '$_baseUrl/api/tracks/${track.id}/stream?auth=$_token',
      );
      final headers = {'Authorization': 'Bearer $_token'};

      // 检查是否有离线缓存
      File? cacheFile;
      if (_cacheService != null) {
        cacheFile = await _cacheService!.getCachedTrack(track.id, track.extension);
      }

      // 移除 `_player.stop()`。just_audio 在调用 setAudioSource 时会自动处理旧的资源释放。
      // 在首次初始化时，调用 stop() 会将内部播放器置于意外状态并导致崩溃 (ExoPlaybackException)

      if (cacheFile != null && await cacheFile.exists()) {
        debugPrint('Playing from cache: ${track.title}');
        await _player.setAudioSource(
          AudioSource.file(cacheFile.path, tag: item),
        );
      } else {
        debugPrint('Playing from network: ${track.title}');
        await _player.setAudioSource(
          AudioSource.uri(networkUri, headers: headers, tag: item),
        );
        
        // 如果是在线播放，则异步触发缓存任务
        if (_cacheService != null) {
          _cacheService!.cacheTrack(
            track,
            networkUri.toString(),
            headers,
            maxCacheBytes: _maxCacheBytes,
          );
        }
      }
      
      // 不必 await 播放开始，让它后台加载。但必须接住可能抛出的异步错误
      _player.play().catchError((e) {
        debugPrint('Async Playback Error: $e');
      });
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
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      notifyListeners();
      await _playCurrentTrack();
    } else if (_player.loopMode == LoopMode.all && _queue.isNotEmpty) {
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
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
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

  Future<void> toggleShuffle() async {
    final enabled = !_player.shuffleModeEnabled;
    await _player.setShuffleModeEnabled(enabled);
    if (enabled) {
      await _player.shuffle();
    }
  }

  Future<void> toggleLoopMode() async {
    switch (_player.loopMode) {
      case LoopMode.off:
        await _player.setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await _player.setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await _player.setLoopMode(LoopMode.off);
        break;
    }
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

/// 由 main.dart 通过 AudioService.init 初始化后注入
final playerHandlerProvider = ChangeNotifierProvider<MusicPlayerHandler>(
  (ref) => throw UnimplementedError('Must override in main.dart'),
);
