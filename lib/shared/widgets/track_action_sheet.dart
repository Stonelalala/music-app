import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/player/player_service.dart';
import '../../core/repositories/collection_repository.dart';
import '../../core/repositories/track_repository.dart';
import '../../features/library/widgets/track_edit_sheet.dart';
import '../../features/my/collection_providers.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import 'modern_toast.dart';

class TrackActionSheet extends ConsumerWidget {
  final Track track;
  final BuildContext hostContext;
  final VoidCallback? onChanged;

  const TrackActionSheet({
    super.key,
    required this.track,
    required this.hostContext,
    this.onChanged,
  });

  static Future<void> show(
    BuildContext context,
    WidgetRef ref,
    Track track, {
    VoidCallback? onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TrackActionSheet(
        track: track,
        hostContext: context,
        onChanged: onChanged,
      ),
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
            _ActionTile(
              icon: Icons.edit_note_rounded,
              label: '编辑歌曲信息',
              onTap: () {
                Navigator.of(context).pop();
                Future<void>.microtask(() {
                  if (hostContext.mounted) {
                    TrackEditSheet.show(hostContext, track, onSaved: onChanged);
                  }
                });
              },
            ),
            favoriteAsync.when(
              data: (isFavorite) => _ActionTile(
                icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                label: isFavorite
                    ? '\u53d6\u6d88\u6536\u85cf'
                    : '\u6536\u85cf\u6b4c\u66f2',
                onTap: () async {
                  Navigator.of(context).pop();
                  await _toggleFavorite(ref, isFavorite);
                },
              ),
              loading: () => const _ActionLoading(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
            _ActionTile(
              icon: Icons.playlist_play_rounded,
              label: '\u4e0b\u4e00\u9996\u64ad\u653e',
              onTap: () async {
                Navigator.of(context).pop();
                await ref
                    .read(playerHandlerProvider)
                    .playTrackPreservingQueue(track);
              },
            ),
            _ActionTile(
              icon: Icons.open_in_full_rounded,
              label: '\u67e5\u770b\u64ad\u653e\u8be6\u60c5',
              onTap: () async {
                Navigator.of(context).pop();
                await ref
                    .read(playerHandlerProvider)
                    .playTrackPreservingQueue(track);
                if (hostContext.mounted) {
                  hostContext.push('/player');
                }
              },
            ),
            playlistsAsync.when(
              data: (playlists) => _ActionTile(
                icon: Icons.queue_music_rounded,
                label: '\u52a0\u5165\u6b4c\u5355',
                onTap: () async {
                  Navigator.of(context).pop();
                  await _showPlaylistPicker(ref, playlists);
                },
              ),
              loading: () => const _ActionLoading(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: '删除歌曲',
              destructive: true,
              onTap: () async {
                Navigator.of(context).pop();
                await _confirmDelete(ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(WidgetRef ref, bool isFavorite) async {
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
      if (hostContext.mounted) {
        ModernToast.show(
          hostContext,
          isFavorite
              ? '\u5df2\u53d6\u6d88\u6536\u85cf'
              : '\u5df2\u52a0\u5165\u6536\u85cf',
          icon: isFavorite ? Icons.heart_broken_outlined : Icons.favorite,
        );
        onChanged?.call();
      }
    } catch (error) {
      if (hostContext.mounted) {
        ModernToast.show(
          hostContext,
          '\u64cd\u4f5c\u5931\u8d25: $error',
          isError: true,
        );
      }
    }
  }

  Future<void> _showPlaylistPicker(
    WidgetRef ref,
    List<UserPlaylist> playlists,
  ) async {
    await showModalBottomSheet<void>(
      context: hostContext,
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
                  '\u52a0\u5165\u6b4c\u5355',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '\u8fd8\u6ca1\u6709\u6b4c\u5355\uff0c\u5148\u53bb\u201c\u6211\u7684\u201d\u9875\u9762\u521b\u5efa\u4e00\u4e2a\u5427\u3002',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ...playlists.map((playlist) {
                  return ListTile(
                    leading: const Icon(Icons.queue_music_rounded),
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.trackCount} \u9996\u6b4c\u66f2'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      try {
                        await ref
                            .read(collectionRepositoryProvider)
                            .addTrackToPlaylist(playlist.id, track.id);
                        ref.invalidate(playlistsProvider);
                        ref.invalidate(playlistDetailProvider(playlist.id));
                        ref.invalidate(playStatsProvider);
                        if (hostContext.mounted) {
                          ModernToast.show(
                            hostContext,
                            '\u5df2\u52a0\u5165 ${playlist.name}',
                          );
                          onChanged?.call();
                        }
                      } catch (error) {
                        if (hostContext.mounted) {
                          ModernToast.show(
                            hostContext,
                            '\u52a0\u5165\u6b4c\u5355\u5931\u8d25: $error',
                            isError: true,
                          );
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

  Future<void> _confirmDelete(WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: hostContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要永久删除歌曲“${track.title}”吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final handler = ref.read(playerHandlerProvider);
      if (handler.currentTrack?.id == track.id) {
        await handler.stop();
      }

      await ref.read(trackRepositoryProvider).deleteTracks([track.id]);
      ref.invalidate(favoriteStatusProvider(track.id));
      ref.invalidate(favoritesProvider);
      ref.invalidate(playlistsProvider);
      ref.invalidate(playStatsProvider);

      if (hostContext.mounted) {
        ModernToast.show(
          hostContext,
          '歌曲已删除',
          icon: Icons.delete_forever_rounded,
        );
        onChanged?.call();
      }
    } catch (error) {
      if (hostContext.mounted) {
        ModernToast.show(hostContext, '删除失败: $error', isError: true);
      }
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        icon,
        color: destructive ? colorScheme.error : colorScheme.onSurface,
      ),
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
