import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/player/player_service.dart';
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
                              // Album Art
                              GestureDetector(
                                onTap: () {
                                  if (!_isExpanded) {
                                    setState(() {
                                      _isExpanded = true;
                                    });
                                  } else {
                                    context.push('/player');
                                  }
                                },
                                child: AnimatedBuilder(
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
                                    width: 56, // Match search button size
                                    height: 56,
                                    margin: EdgeInsets.only(
                                      left: _isExpanded ? 0 : 8,
                                      right: _isExpanded ? 0 : 8,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1.5,
                                      ),
                                      // 仅在折叠态提供一个阴影以增强悬浮感
                                      boxShadow: !_isExpanded
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.5,
                                                ),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ClipOval(
                                      child: Image.network(
                                        '${item.artUri}',
                                        key: ValueKey(item.id),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
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
                              ),
                              if (_isExpanded) ...[
                                const SizedBox(width: 12),
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
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: AppTheme.bgBase,
                                      size: 28,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Next
                                IconButton(
                                  icon: const Icon(
                                    Icons.skip_next,
                                    color: AppTheme.textPrimary,
                                    size: 24,
                                  ),
                                  onPressed: () => handler.skipToNext(),
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
