import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/player/player_service.dart';
import '../../shared/widgets/global_playlist.dart';
import '../../shared/theme/app_theme.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handler = ref.watch(playerHandlerProvider);

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();

        return StreamBuilder<bool>(
          stream: handler.player.playingStream,
          builder: (context, playingSnap) {
            final isPlaying = playingSnap.data ?? false;
            if (isPlaying) {
              _rotationController.repeat();
            } else {
              _rotationController.stop();
            }

            return Align(
              alignment: Alignment.centerRight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: 72,
                width: _isExpanded ? MediaQuery.of(context).size.width : 72,
                margin: EdgeInsets.fromLTRB(
                  _isExpanded ? 12 : 0,
                  0,
                  _isExpanded ? 12 : 8, // Add some right margin when collapsed
                  12,
                ),
                child: Stack(
                  children: [
                    // 毛玻璃背景层，仅在胶囊区域有效
                    if (_isExpanded)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.horizontal(
                            left: const Radius.circular(40),
                            right: Radius.circular(_isExpanded ? 40 : 0),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    // 前景内容区
                    Container(
                      decoration: BoxDecoration(
                        color: _isExpanded
                            ? const Color(0xFF1E1E1E).withOpacity(0.4)
                            : Colors
                                  .transparent, // True floating when collapsed
                        borderRadius: BorderRadius.horizontal(
                          left: const Radius.circular(40),
                          right: Radius.circular(_isExpanded ? 40 : 0),
                        ),
                        border: _isExpanded
                            ? Border.all(
                                color: Colors.white.withOpacity(0.05),
                                width: 1,
                              )
                            : null,
                      ),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: _isExpanded
                              ? MediaQuery.of(context).size.width - 24
                              : 72,
                          child: Row(
                            children: [
                              if (_isExpanded)
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _isExpanded = false;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              if (_isExpanded) const SizedBox(width: 4),
                              // Album Art with Progress Ring
                              StreamBuilder<Duration>(
                                stream: AudioService.position,
                                builder: (context, posSnap) {
                                  final position =
                                      posSnap.data ?? Duration.zero;
                                  final duration =
                                      item.duration ?? Duration.zero;
                                  final progress = duration.inMilliseconds > 0
                                      ? position.inMilliseconds /
                                            duration.inMilliseconds
                                      : 0.0;

                                  return GestureDetector(
                                    onTap: () {
                                      if (!_isExpanded) {
                                        setState(() {
                                          _isExpanded = true;
                                        });
                                      } else {
                                        context.push('/player');
                                      }
                                    },
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Progress Ring
                                        CustomPaint(
                                          size: const Size(64, 64),
                                          painter: _CircularProgressPainter(
                                            progress: progress,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            backgroundColor: Colors.white
                                                .withOpacity(0.1),
                                          ),
                                        ),
                                        AnimatedBuilder(
                                          animation: _rotationController,
                                          builder: (context, child) {
                                            return Transform.rotate(
                                              angle:
                                                  _rotationController.value *
                                                  2 *
                                                  3.1415926,
                                              alignment: Alignment.center,
                                              child: child,
                                            );
                                          },
                                          child: Container(
                                            width:
                                                52, // Slightly smaller than progress ring
                                            height: 52,
                                            margin: EdgeInsets.only(
                                              left: _isExpanded ? 0 : 8,
                                              right: _isExpanded ? 0 : 8,
                                            ),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              // 仅在折叠态提供一个阴影以增强悬浮感
                                              boxShadow: !_isExpanded
                                                  ? [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.5),
                                                        blurRadius: 12,
                                                        offset: const Offset(
                                                          0,
                                                          4,
                                                        ),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: ClipOval(
                                              child: Image.network(
                                                '${item.artUri}',
                                                key: ValueKey(item.id),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                      color: AppTheme
                                                          .surfaceElevated,
                                                      child: const Icon(
                                                        Icons.music_note,
                                                        color: AppTheme.accent,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (_isExpanded) ...[
                                const SizedBox(
                                  width: 8,
                                ), // Adjusted from 12 to 8 because of progress ring spacing
                                // Info
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => context.push('/player'),
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${item.artist} — ${item.album}',
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Play/Pause
                                GestureDetector(
                                  onTap: () => isPlaying
                                      ? handler.pause()
                                      : handler.play(),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.playlist_play_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    size: 24,
                                  ),
                                  onPressed: () =>
                                      GlobalPlaylist.show(context, ref),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 3.0;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    canvas.drawArc(
      rect,
      -3.1415926 / 2,
      2 * 3.1415926 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
