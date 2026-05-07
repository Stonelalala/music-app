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
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
              colorScheme.surfaceContainer.withValues(alpha: 0.94),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.24,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ActionSheetHeader(track: track),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Column(
                    children: [
                      _ActionTile(
                        icon: Icons.edit_note_rounded,
                        label: '\u7f16\u8f91\u6b4c\u66f2\u4fe1\u606f',
                        subtitle:
                            '\u4fee\u6539\u6807\u9898\u3001\u6b4c\u624b\u3001\u4e13\u8f91\u4e0e\u5e74\u4efd',
                        onTap: () {
                          Navigator.of(context).pop();
                          Future<void>.microtask(() {
                            if (hostContext.mounted) {
                              TrackEditSheet.show(
                                hostContext,
                                track,
                                onSaved: onChanged,
                              );
                            }
                          });
                        },
                      ),
                      favoriteAsync.when(
                        data: (isFavorite) => _ActionTile(
                          icon: isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: isFavorite
                              ? '\u53d6\u6d88\u6536\u85cf'
                              : '\u6536\u85cf\u6b4c\u66f2',
                          subtitle: isFavorite
                              ? '\u4ece\u6211\u7684\u6536\u85cf\u4e2d\u79fb\u9664'
                              : '\u4fdd\u5b58\u5230\u6211\u7684\u6536\u85cf',
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _toggleFavorite(ref, isFavorite);
                          },
                        ),
                        loading: () => const _ActionLoading(),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                      ),
                      playlistsAsync.when(
                        data: (playlists) => _ActionTile(
                          icon: Icons.library_add_rounded,
                          label: '\u52a0\u5165\u6b4c\u5355',
                          subtitle:
                              '\u6536\u8fdb\u4f60\u7684\u81ea\u5efa\u6b4c\u5355',
                          onTap: () async {
                            Navigator.of(context).pop();
                            await _showPlaylistPicker(ref, playlists);
                          },
                        ),
                        loading: () => const _ActionLoading(),
                        error: (error, stackTrace) => const SizedBox.shrink(),
                      ),
                      _ActionTile(
                        icon: Icons.playlist_play_rounded,
                        label: '\u4e0b\u4e00\u9996\u64ad\u653e',
                        subtitle:
                            '\u4fdd\u7559\u5f53\u524d\u961f\u5217\u5e76\u63d2\u5165\u4e0b\u4e00\u9996',
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
                        subtitle:
                            '\u7acb\u5373\u6253\u5f00\u64ad\u653e\u5668\u5e76\u5bf9\u9f50\u5230\u8fd9\u9996\u6b4c',
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
                      _ActionTile(
                        icon: Icons.delete_outline_rounded,
                        label: '\u5220\u9664\u6b4c\u66f2',
                        subtitle:
                            '\u4ece\u8d44\u6599\u5e93\u4e2d\u6c38\u4e45\u79fb\u9664',
                        destructive: true,
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _confirmDelete(ref);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.18),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.24,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '\u52a0\u5165\u6b4c\u5355',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\u9009\u4e00\u4e2a\u6b4c\u5355\u4fdd\u5b58\u8fd9\u9996\u6b4c',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    if (playlists.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.44),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          '\u8fd8\u6ca1\u6709\u6b4c\u5355\uff0c\u53ef\u4ee5\u5148\u5230\u201c\u6211\u7684\u201d\u9875\u521b\u5efa\u3002',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    else
                      ...playlists.map((playlist) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PlaylistTile(
                            playlist: playlist,
                            onTap: () async {
                              Navigator.of(context).pop();
                              try {
                                await ref
                                    .read(collectionRepositoryProvider)
                                    .addTrackToPlaylist(playlist.id, track.id);
                                ref.invalidate(playlistsProvider);
                                ref.invalidate(
                                  playlistDetailProvider(playlist.id),
                                );
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
                          ),
                        );
                      }),
                  ],
                ),
              ),
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
        title: const Text('\u786e\u8ba4\u5220\u9664'),
        content: Text(
          '\u786e\u5b9a\u8981\u6c38\u4e45\u5220\u9664\u300c${track.title}\u300d\u5417\uff1f\u6b64\u64cd\u4f5c\u4e0d\u53ef\u64a4\u9500\u3002',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('\u53d6\u6d88'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('\u5220\u9664'),
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
          '\u6b4c\u66f2\u5df2\u5220\u9664',
          icon: Icons.delete_forever_rounded,
        );
        onChanged?.call();
      }
    } catch (error) {
      if (hostContext.mounted) {
        ModernToast.show(
          hostContext,
          '\u5220\u9664\u5931\u8d25: $error',
          isError: true,
        );
      }
    }
  }
}

class _ActionSheetHeader extends StatelessWidget {
  const _ActionSheetHeader({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.12),
            colorScheme.tertiary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.music_note_rounded,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaBadge(label: track.album),
                    _MetaBadge(
                      label: track.extension.replaceAll('.', '').toUpperCase(),
                    ),
                    _MetaBadge(label: track.sizeText),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = destructive ? colorScheme.error : colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: destructive
                    ? colorScheme.error.withValues(alpha: 0.12)
                    : colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: destructive ? colorScheme.error : colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist, required this.onTap});

  final UserPlaylist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.46),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.queue_music_rounded,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.trackCount} \u9996\u6b4c\u66f2',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _ActionLoading extends StatelessWidget {
  const _ActionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
