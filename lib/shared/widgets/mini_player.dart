import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/player/player_service.dart';
import '../../shared/widgets/global_playlist.dart';

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
    final handler = ref.read(playerHandlerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final expandedWidth = MediaQuery.of(context).size.width - 44;

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
              if (!_rotationController.isAnimating) {
                _rotationController.repeat();
              }
            } else if (_rotationController.isAnimating) {
              _rotationController.stop();
            }

            return SizedBox(
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerRight,
                heightFactor: 1,
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity == null) return;
                    if (details.primaryVelocity! > 200 && _isExpanded) {
                      setState(() => _isExpanded = false);
                    } else if (details.primaryVelocity! < -200 &&
                        !_isExpanded) {
                      setState(() => _isExpanded = true);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    height: 68,
                    width: _isExpanded ? expandedWidth : 148,
                    margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.surfaceContainerHigh.withValues(
                                  alpha: 0.94,
                                ),
                                colorScheme.surfaceContainer.withValues(
                                  alpha: 0.88,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.14,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                if (_isExpanded)
                                  InkWell(
                                    onTap: () =>
                                        setState(() => _isExpanded = false),
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: 24,
                                      height: 48,
                                      child: Icon(
                                        Icons.chevron_right_rounded,
                                        color: colorScheme.onSurfaceVariant,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                if (_isExpanded) const SizedBox(width: 2),
                                _MiniPlayerArtwork(
                                  item: item,
                                  isExpanded: _isExpanded,
                                  rotationController: _rotationController,
                                  positionStream:
                                      handler.player.positionStream,
                                  onTap: () {
                                    if (!_isExpanded) {
                                      setState(() => _isExpanded = true);
                                    } else {
                                      context.push('/player');
                                    }
                                  },
                                ),
                                const SizedBox(width: 10),
                                if (_isExpanded)
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => context.push('/player'),
                                      borderRadius: BorderRadius.circular(18),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colorScheme.onSurface,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              item.artist ?? '',
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_isExpanded) const SizedBox(width: 8),
                                _MiniPlayerIconButton(
                                  icon: isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  emphasized: true,
                                  onTap: () => isPlaying
                                      ? handler.pause()
                                      : handler.play(),
                                ),
                                const SizedBox(width: 6),
                                _MiniPlayerIconButton(
                                  icon: Icons.skip_next_rounded,
                                  onTap: () => handler.skipToNext(),
                                ),
                                if (_isExpanded) ...[
                                  const SizedBox(width: 4),
                                  _MiniPlayerIconButton(
                                    icon: Icons.playlist_play_rounded,
                                    onTap: () =>
                                        GlobalPlaylist.show(context, ref),
                                  ),
                                ] else ...[
                                  const SizedBox(width: 2),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _MiniPlayerArtwork extends StatelessWidget {
  const _MiniPlayerArtwork({
    required this.item,
    required this.isExpanded,
    required this.rotationController,
    required this.positionStream,
    required this.onTap,
  });

  final MediaItem item;
  final bool isExpanded;
  final AnimationController rotationController;
  final Stream<Duration> positionStream;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<Duration>(
      stream: positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        final duration = item.duration ?? Duration.zero;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        final outerSize = isExpanded ? 52.0 : 50.0;
        final artworkSize = isExpanded ? 42.0 : 40.0;

        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: outerSize,
            height: outerSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(outerSize),
                  painter: _CircularProgressPainter(
                    progress: progress.clamp(0.0, 1.0),
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.onSurface.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: rotationController.value * 2 * 3.1415926,
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: Container(
                    width: artworkSize,
                    height: artworkSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: '${item.artUri}',
                        cacheKey: 'cover_${item.id}',
                        key: ValueKey(item.id),
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: colorScheme.surfaceContainerHighest,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.music_note_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
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
  }
}

class _MiniPlayerIconButton extends StatelessWidget {
  const _MiniPlayerIconButton({
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: emphasized ? 36 : 32,
        height: emphasized ? 36 : 32,
        decoration: BoxDecoration(
          color: emphasized
              ? colorScheme.primary
              : colorScheme.surface.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: emphasized ? colorScheme.onPrimary : colorScheme.onSurface,
          size: emphasized ? 20 : 18,
        ),
      ),
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
