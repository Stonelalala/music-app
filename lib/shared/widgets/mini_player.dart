import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/player/player_service.dart';
import '../../shared/theme/app_theme.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.watch(playerHandlerProvider);

    return StreamBuilder<MediaItem?>(
      stream: handler.mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => context.push('/player'),
          child: Container(
            height: 72,
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF08140E),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: AppTheme.border, width: 1),
            ),
            child: Row(
              children: [
                // Album Art
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    '${item.artUri}',
                    key: ValueKey(item.id), // 重要：ID 变化时刷新图片
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: AppTheme.surfaceElevated,
                      child: const Icon(
                        Icons.music_note,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Controls
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous,
                    color: AppTheme.textPrimary,
                    size: 24,
                  ),
                  onPressed: () => handler.skipToPrevious(),
                ),
                StreamBuilder<bool>(
                  stream: handler.player.playingStream,
                  builder: (context, snap) {
                    final playing = snap.data ?? false;
                    return GestureDetector(
                      onTap: () => playing ? handler.pause() : handler.play(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          color: AppTheme.bgBase,
                          size: 28,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.skip_next,
                    color: AppTheme.textPrimary,
                    size: 24,
                  ),
                  onPressed: () => handler.skipToNext(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
