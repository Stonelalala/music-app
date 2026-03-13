import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/player/player_service.dart';
import '../../core/repositories/collection_repository.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../../features/my/collection_providers.dart';
import 'modern_toast.dart';

class TrackActionSheet extends ConsumerWidget {
  final Track track;

  const TrackActionSheet({super.key, required this.track});

  static Future<void> show(BuildContext context, WidgetRef ref, Track track) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => TrackActionSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final favoriteAsync = ref.watch(favoriteStatusProvider(track.id));
    final playlistsAsync = ref.watch(playlistsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            favoriteAsync.when(
              data: (isFavorite) => _ActionTile(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                label: isFavorite ? '取消收藏' : '收藏歌曲',
                onTap: () async {
                  Navigator.of(context).pop();
                  await _toggleFavorite(context, ref, isFavorite);
                },
              ),
              loading: () => const _ActionLoading(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
            _ActionTile(
              icon: Icons.playlist_play_rounded,
              label: '下一首播放',
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(playerHandlerProvider).playTrackPreservingQueue(track);
              },
            ),
            _ActionTile(
              icon: Icons.open_in_full_rounded,
              label: '查看播放详情',
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(playerHandlerProvider).playTrackPreservingQueue(track);
                if (context.mounted) {
                  context.push('/player');
                }
              },
            ),
            playlistsAsync.when(
              data: (playlists) => _ActionTile(
                icon: Icons.queue_music_rounded,
                label: '加入歌单',
                onTap: () async {
                  Navigator.of(context).pop();
                  await _showPlaylistPicker(context, ref, playlists);
                },
              ),
              loading: () => const _ActionLoading(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    bool isFavorite,
  ) async {
    try {
      final repo = ref.read(collectionRepositoryProvider);
      if (isFavorite) {
        await repo.removeFavorite(track.id);
      } else {
        await repo.addFavorite(track.id);
      }
      ref.invalidate(favoriteStatusProvider(track.id));
      ref.invalidate(favoritesProvider);
      ref.invalidate(playStatsProvider);
      if (context.mounted) {
        ModernToast.show(
          context,
          isFavorite ? '已取消收藏' : '已加入收藏',
          icon: isFavorite ? Icons.heart_broken_outlined : Icons.favorite,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ModernToast.show(context, '操作失败: $e', isError: true);
      }
    }
  }

  Future<void> _showPlaylistPicker(
    BuildContext context,
    WidgetRef ref,
    List<UserPlaylist> playlists,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '加入歌单',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '还没有歌单，先去“我的”页创建一个吧。',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ...playlists.map((playlist) {
                  return ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.trackCount} 首歌曲'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      try {
                        await ref
                            .read(collectionRepositoryProvider)
                            .addTrackToPlaylist(playlist.id, track.id);
                        ref.invalidate(playlistsProvider);
                        ref.invalidate(playlistDetailProvider(playlist.id));
                        ref.invalidate(playStatsProvider);
                        if (context.mounted) {
                          ModernToast.show(context, '已加入 ${playlist.name}');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ModernToast.show(context, '加入歌单失败: $e', isError: true);
                        }
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _ActionLoading extends StatelessWidget {
  const _ActionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
