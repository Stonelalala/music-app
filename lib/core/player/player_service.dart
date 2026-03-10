import 'dart:io';
import 'package:http/http.dart' as http;
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
  List<_LyricLine> _currentLyrics = [];
  int _lastLyricIndex = -1;

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

    // 监听进度以同步更新系统歌词
    _player.positionStream.listen(_updateLyricInMetadata);
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
    _queue = List.from(tracks); // 关键修正：复制列表，确保它是可变的
    _currentIndex = startIndex;
    notifyListeners();
    await _playCurrentTrack();
  }

  /// 播放单首曲目（替换队列）
  Future<void> playSingle(Track track) async {
    _queue = [track]; // 字面量创建的列表是可变的
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

    // 清空当前歌词状态并异步获取新歌词
    _currentLyrics = [];
    _lastLyricIndex = -1;
    _fetchAndParseLyrics(track.id);
    _recordPlayback(track.id);

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
  Future<void> stop() async {
    _currentLyrics = [];
    _lastLyricIndex = -1;
    await _player.stop();
  }

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

  /// 当歌曲元数据修改（如歌手）后，刷新当前正在播放的曲目信息
  void refreshTrackMetadata(Track updatedTrack) {
    if (_queue.isEmpty || _currentIndex < 0 || _currentIndex >= _queue.length) return;
    
    // 检查是否是当前正在播放的歌曲
    if (_queue[_currentIndex].id == updatedTrack.id) {
      _queue[_currentIndex] = updatedTrack;
      // 重新推送到系统媒介控制器
      _updateMediaItemWithLyric(_lastLyricIndex != -1 && _currentLyrics.isNotEmpty 
          ? _currentLyrics[_lastLyricIndex].text 
          : updatedTrack.artist);
      notifyListeners();
    } else {
      // 遍历列表更新匹配的歌曲
      for (int i = 0; i < _queue.length; i++) {
        if (_queue[i].id == updatedTrack.id) {
          _queue[i] = updatedTrack;
          notifyListeners();
          break;
        }
      }
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

  Future<void> _fetchAndParseLyrics(String trackId) async {
    final lyrics = await getLyrics(trackId);
    if (lyrics != null) {
      _currentLyrics = _parseLrc(lyrics);
      // 立即触发一次更新
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
    final track = currentTrack;
    if (track == null) return;

    final item = mediaItem.value;
    if (item == null) return;

    // 针对 ColorOS 16 / 国内定制 ROM 的深度优化方案：
    // 1. 系统卡片通常只展示 Title 和 Artist 两个大字。
    // 2. 将 Artist 字段实时替换为歌词文本，这是目前最通用的“通知栏歌词”实现方式。
    // 3. 同时设置 displaySubtitle 和 extras 以适配部分支持原生歌词字段的系统。
    
    final String displayArtist = lyric ?? track.artist;

    // 性能优化：只有在显示文本真正变化时才推送更新给系统
    if (item.artist == displayArtist && item.displaySubtitle == lyric) return;

    mediaItem.add(MediaItem(
      id: track.id,
      title: track.title,
      artist: displayArtist, // 核心改动：用歌词占据歌手位置
      album: track.album,
      duration: Duration(seconds: track.duration.toInt()),
      artUri: item.artUri,
      displayTitle: track.title,
      displaySubtitle: lyric,
      displayDescription: lyric, // 增加描述字段兼容性
      extras: {
        'lyric': lyric,
        'android.media.metadata.LYRIC': lyric, // 某些 ROM 识别此字段
        'real_artist': track.artist, // 在 extras 里保留一份原始歌手信息
      },
    ));
  }

  List<_LyricLine> _parseLrc(String lrc) {
    final List<_LyricLine> lines = [];
    final reg = RegExp(r'\[(\d+):(\d+\.?\d*)\](.*)');
    for (var line in lrc.split('\n')) {
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
      await http.post(
        Uri.parse('$_baseUrl/api/tracks/$trackId/play'),
        headers: {'Authorization': 'Bearer $_token'},
      );
    } catch (e) {
      debugPrint('Error recording playback: $e');
    }
  }

  @override
  Future<void> onTaskRemoved() => stop();
}

class _LyricLine {
  final Duration time;
  final String text;
  _LyricLine({required this.time, required this.text});
}

/// 由 main.dart 通过 AudioService.init 初始化后注入
final playerHandlerProvider = ChangeNotifierProvider<MusicPlayerHandler>(
  (ref) => throw UnimplementedError('Must override in main.dart'),
);
