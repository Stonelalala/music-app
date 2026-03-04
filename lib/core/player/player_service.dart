import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../shared/models/track.dart';

class MusicPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  List<Track> _queue = [];
  int _currentIndex = 0;
  String? _token;
  String? _baseUrl;

  MusicPlayerHandler() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  void setAuth(String token, String baseUrl) {
    _token = token;
    _baseUrl = baseUrl;
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
    await _playCurrentTrack();
  }

  /// 播放单首曲目（替换队列）
  Future<void> playSingle(Track track) async {
    _queue = [track];
    _currentIndex = 0;
    await _playCurrentTrack();
  }

  Future<void> _playCurrentTrack() async {
    final track = currentTrack;
    if (track == null || _token == null || _baseUrl == null) return;

    // 先推送到系统媒介控制器，让 UI/通知栏立刻显示
    mediaItem.add(
      MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: Duration(seconds: track.duration.toInt()),
        artUri: Uri.parse(
          '$_baseUrl/api/tracks/${track.id}/cover?auth=$_token',
        ),
      ),
    );

    try {
      final uri = Uri.parse(
        '$_baseUrl/api/tracks/${track.id}/stream?auth=$_token',
      );
      // 如果之前有正在播放或加载的，先强制停止以清理资源
      if (_player.playing || _player.processingState != ProcessingState.idle) {
        await _player.stop();
      }
      await _player.setAudioSource(AudioSource.uri(uri));
      _player.play(); // 不必 await 播放开始，让它后台加载
    } catch (e) {
      debugPrint('Playback error: $e');
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
      await _playCurrentTrack();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _playCurrentTrack();
    } else {
      await _player.seek(Duration.zero);
    }
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
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
      ),
    );
  }

  @override
  Future<void> onTaskRemoved() => stop();
}

/// 由 main.dart 通过 AudioService.init 初始化后注入
final playerHandlerProvider = Provider<MusicPlayerHandler>(
  (ref) => throw UnimplementedError('Must override in main.dart'),
  name: 'playerHandlerProvider',
);
