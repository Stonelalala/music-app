import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import 'package:music/shared/widgets/playlist_sheet.dart';

import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../shared/models/track.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _lyricScrollController = ScrollController();
  late AnimationController _rotationController;
  List<_LyricLine> _parsedLyrics = [];
  int _currentLyricIndex = -1;
  StreamSubscription? _posSubscription;
  StreamSubscription? _playingSubscription;
  String? _lastTrackId;

  // 杩涘害鏉℃嫋鍔ㄤ紭鍖栵細璁板綍鏈湴鎷栧姩鍊?
  double? _draggingValue;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _setupListeners();
  }

  void _setupListeners() {
    final handler = ref.read(playerHandlerProvider);
    _posSubscription = handler.player.positionStream.listen((pos) {
      if (_parsedLyrics.isNotEmpty) {
        _updateLyricHighlight(pos);
      }
    });
    _playingSubscription = handler.player.playingStream.listen((playing) {
      if (playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });
    if (handler.player.playing) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(PlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAndFetchLyrics();
  }

  void _checkAndFetchLyrics() {
    final handler = ref.read(playerHandlerProvider);
    final track = handler.currentTrack;
    if (track != null && track.id != _lastTrackId) {
      debugPrint('Track changed in PlayerPage: ${track.title}');
      _lastTrackId = track.id;
      setState(() {
        _parsedLyrics = [];
        _currentLyricIndex = -1;
      });
      _fetchLyrics(track.id);
    }
  }

  Future<void> _fetchLyrics(String trackId) async {
    final lyrics = await ref.read(playerHandlerProvider).getLyrics(trackId);
    if (mounted && lyrics != null) {
      setState(() {
        _parsedLyrics = _parseLrc(lyrics);
      });
    }
  }

  void _updateLyricHighlight(Duration pos) {
    int index = -1;
    for (int i = 0; i < _parsedLyrics.length; i++) {
      if (pos >= _parsedLyrics[i].time) {
        index = i;
      } else {
        break;
      }
    }

    if (index != _currentLyricIndex && index != -1) {
      if (mounted) {
        setState(() {
          _currentLyricIndex = index;
        });
        final isSmall = MediaQuery.of(context).size.height < 680;
        _scrollToCurrentLyric(isSmall ? 30.0 : 34.0);
      }
    }
  }

  void _scrollToCurrentLyric(double itemHeight) {
    if (_lyricScrollController.hasClients && _currentLyricIndex != -1) {
      _lyricScrollController.animateTo(
        _currentLyricIndex * itemHeight,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _posSubscription?.cancel();
    _playingSubscription?.cancel();
    _rotationController.dispose();
    _lyricScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 鐩戝惉 handler 鍙樺寲浠ヨЕ鍙?UI 鍒锋柊
    final handler = ref.watch(playerHandlerProvider);
    final auth = ref.watch(authServiceProvider);
    
    // 姣忔 build 妫€鏌ユ瓕鏇叉槸鍚﹀彉鍖栵紙鍒囨瓕锛?
    _checkAndFetchLyrics();
    
    final track = handler.currentTrack;
    if (track == null) return const Scaffold();

    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 72,
        leading: IconButton(
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 30,
            color: colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.playlist_play_rounded,
              color: colorScheme.onSurface,
              size: 28,
            ),
            onPressed: () => GlobalPlaylist.show(context, ref),
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
        title: Builder(
          builder: (context) {
            final currentTrack = handler.currentTrack ?? track;
            return RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: currentTrack.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(
                    text: ' - ${currentTrack.artist}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxHeight < 680;
            final cdSize = isSmallScreen ? 140.0 : 200.0;
            final itemHeight = isSmallScreen ? 28.0 : 32.0;
            final lyricsHeight = itemHeight * 5;
            final spacingHeight = isSmallScreen ? 4.0 : 12.0;

            return Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // CD Disk with Glow Effect
                      _buildCDDiskPremium(
                        handler.currentTrack ?? track,
                        baseUrl,
                        token,
                        colorScheme.primary,
                        cdSize,
                        colorScheme,
                      ),
                      SizedBox(height: spacingHeight * 2),
                      // Lyrics View
                      SizedBox(
                        height: lyricsHeight,
                        child: _buildLyricViewPremium(
                          colorScheme,
                          isSmallScreen ? 14.0 : 16.0,
                          itemHeight,
                          lyricsHeight,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom Control Card (Translucent, responsive theme)
                _buildControlCard(
                  context,
                  handler,
                  handler.currentTrack ?? track,
                  colorScheme,
                  isSmallScreen,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCDDiskPremium(
    Track track,
    String baseUrl,
    String token,
    Color accentColor,
    double size,
    ColorScheme colorScheme,
  ) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Glow
            Container(
              width: size + 20,
              height: size + 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
            // The Disk
            Transform.rotate(
              angle: _rotationController.value * 2 * pi,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(
                          '$baseUrl/api/tracks/${track.id}/cover?auth=$token',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Center Pin
            Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface,
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: size * 0.05,
                  height: size * 0.05,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlCard(
    BuildContext context,
    MusicPlayerHandler handler,
    Track track,
    ColorScheme colorScheme,
    bool isSmall,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress Bar
                StreamBuilder<Duration>(
                  stream: handler.player.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = Duration(seconds: track.duration.toInt());
                    
                    // 濡傛灉姝ｅ湪鎷栧姩锛屼娇鐢ㄦ嫋鍔ㄦ椂鐨勫€硷紝鍚﹀垯浣跨敤鎾斁鍣ㄥ綋鍓嶈繘搴?
                    final currentSeconds = _draggingValue ?? pos.inSeconds.toDouble();
                    
                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6, // 澧炲姞婊戝潡澶у皬锛屾彁鍗囦氦浜掓劅
                            ),
                            activeTrackColor: colorScheme.primary,
                            inactiveTrackColor: colorScheme.onSurface
                                .withValues(alpha: 0.1),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                          ),
                          child: Slider(
                            value: currentSeconds.clamp(
                              0.0,
                              dur.inSeconds.toDouble() > 0 ? dur.inSeconds.toDouble() : 1.0,
                            ),
                            max: dur.inSeconds.toDouble() > 0
                                ? dur.inSeconds.toDouble()
                                : 1.0,
                            onChangeStart: (v) {
                              setState(() {
                                _draggingValue = v;
                              });
                            },
                            onChanged: (v) {
                              setState(() {
                                _draggingValue = v;
                              });
                            },
                            onChangeEnd: (v) {
                              handler.seek(Duration(seconds: v.toInt()));
                              setState(() {
                                _draggingValue = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(Duration(seconds: currentSeconds.toInt())),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _formatDuration(dur),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Main Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StreamBuilder<bool>(
                      stream: handler.player.shuffleModeEnabledStream,
                      builder: (context, snap) => IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: (snap.data ?? false)
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          size: 22,
                        ),
                        onPressed: () => handler.toggleShuffle(),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        color: colorScheme.onSurface,
                        size: 36,
                      ),
                      onPressed: () => handler.skipToPrevious(),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: handler.player.playerStateStream,
                      builder: (context, snapshot) {
                        final playerState = snapshot.data;
                        final processingState = playerState?.processingState;
                        final playing = playerState?.playing ?? false;

                        // 鏄惁澶勪簬鍔犺浇鎴栫紦鍐茬姸鎬?
                        final isLoading = processingState == ProcessingState.buffering ||
                                         processingState == ProcessingState.loading;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // 鍥哄畾 72x72 鐨勭┖闂达紝闃叉鍔犺浇鐜嚭鐜?娑堝け鏃?UI 鏁翠綋鍙戠敓浣嶇Щ
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 300),
                                opacity: isLoading ? 1.0 : 0.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => playing ? handler.pause() : handler.play(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: colorScheme.onPrimary,
                                  size: 36,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        color: colorScheme.onSurface,
                        size: 36,
                      ),
                      onPressed: () => handler.skipToNext(),
                    ),
                    StreamBuilder<LoopMode>(
                      stream: handler.player.loopModeStream,
                      builder: (context, snap) {
                        final mode = snap.data ?? LoopMode.off;
                        return IconButton(
                          icon: Icon(
                            mode == LoopMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: mode != LoopMode.off
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                            size: 22,
                          ),
                          onPressed: () => handler.toggleLoopMode(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricViewPremium(
    ColorScheme colorScheme,
    double activeFontSize,
    double itemHeight,
    double lyricsHeight,
  ) {
    if (_parsedLyrics.isEmpty) {
      return Center(
        child: Text(
          '鏆傛棤姝岃瘝',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _lyricScrollController,
      itemCount: _parsedLyrics.length,
      physics: const NeverScrollableScrollPhysics(), // Prevent conflict with parent scroll
      padding: EdgeInsets.symmetric(vertical: (lyricsHeight - itemHeight) / 2),
      itemExtent: itemHeight,
      itemBuilder: (context, i) {
        final isCurrent = i == _currentLyricIndex;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isCurrent ? 1.0 : 0.3,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: isCurrent
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
              fontSize: isCurrent ? activeFontSize : activeFontSize - 2,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w400,
            ),
            textAlign: TextAlign.center,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _parsedLyrics[i].text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
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

  String _formatDuration(Duration d) {
    if (d.inSeconds < 0) return '0:00';
    final m = d.inMinutes.toString();
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _LyricLine {
  final Duration time;
  final String text;
  _LyricLine({required this.time, required this.text});
}

