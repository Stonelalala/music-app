import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  // 手势识别：向右划收缩，向左划展开
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! > 200) {
                      // 向右划
                      if (_isExpanded) setState(() => _isExpanded = false);
                    } else if (details.primaryVelocity! < -200) {
                      // 向左划
                      if (!_isExpanded) setState(() => _isExpanded = true);
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  height: 56,
                  width: _isExpanded ? MediaQuery.of(context).size.width - 72 : 148,
                  margin: const EdgeInsets.fromLTRB(36, 0, 36, 16),
                  child: Stack(
                    children: [
                      // 毛玻璃背景层
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      // 前景内容区
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                            width: 1,
                          ),
                        ),
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: _isExpanded
                                ? MediaQuery.of(context).size.width - 72
                                : 148,
                            child: Row(
                              children: [
                                if (_isExpanded)
                                  SizedBox(
                                    width: 24,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          _isExpanded = false;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        color: AppTheme.textSecondary,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                if (_isExpanded) const SizedBox(width: 4),
                                // Album Art with Progress Ring
                                StreamBuilder<Duration>(
                                  stream: AudioService.position,
                                  builder: (context, posSnap) {
                                    final position = posSnap.data ?? Duration.zero;
                                    final duration = item.duration ?? Duration.zero;
                                    final progress = duration.inMilliseconds > 0
                                        ? position.inMilliseconds / duration.inMilliseconds
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
                                            size: const Size(56, 56),
                                            painter: _CircularProgressPainter(
                                              progress: progress,
                                              color: Theme.of(context).colorScheme.primary,
                                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                                            ),
                                          ),
                                          AnimatedBuilder(
                                            animation: _rotationController,
                                            builder: (context, child) {
                                              return Transform.rotate(
                                                angle: _rotationController.value * 2 * 3.1415926,
                                                alignment: Alignment.center,
                                                child: child,
                                              );
                                            },
                                            child: Container(
                                              width: 48,
                                              height: 48,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                              ),
                                              child: ClipOval(
                                                child: CachedNetworkImage(
                                                  imageUrl: '${item.artUri}',
                                                  cacheKey: 'cover_${item.id}',
                                                  key: ValueKey(item.id),
                                                  fit: BoxFit.cover,
                                                  errorWidget: (context, url, error) => Container(
                                                    color: AppTheme.surfaceElevated,
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
                                const SizedBox(width: 8),
                                // Info
                                if (_isExpanded)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => context.push('/player'),
                                      behavior: HitTestBehavior.opaque,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.artist ?? '',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary.withValues(alpha: 0.9),
                                              fontSize: 11,
                                              fontStyle: (item.artist?.startsWith('[') ?? false)
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Controls group
                                GestureDetector(
                                  onTap: () => isPlaying ? handler.pause() : handler.play(),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 32,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => handler.skipToNext(),
                                    icon: Icon(
                                      Icons.skip_next_rounded,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                if (_isExpanded) ...[
                                  SizedBox(
                                    width: 32,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        Icons.playlist_play_rounded,
                                        color: Theme.of(context).colorScheme.onSurface,
                                        size: 22,
                                      ),
                                      onPressed: () => GlobalPlaylist.show(context, ref),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (!_isExpanded)
                                  const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
