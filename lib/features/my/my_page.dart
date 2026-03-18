import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/player/cache_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/collection_repository.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/modern_toast.dart';
import '../../shared/widgets/playlist_detail_sheet.dart';
import '../../shared/widgets/track_action_sheet.dart';
import 'collection_providers.dart';

class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(playStatsProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final playlistsAsync = ref.watch(playlistsProvider);
    final historyAsync = ref.watch(recentHistoryProvider);
    final cachedAsync = ref.watch(cachedTracksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            onPressed: () => _showCreatePlaylistDialog(context, ref),
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: '新建歌单',
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(playStatsProvider);
          ref.invalidate(favoritesProvider);
          ref.invalidate(playlistsProvider);
          ref.invalidate(recentHistoryProvider);
          ref.invalidate(cachedTracksProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            statsAsync.when(
              data: (stats) => LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 720;
                  final cards = [
                    _StatCard(
                      label: '总播放',
                      value: '${stats.totalPlays}',
                      icon: Icons.graphic_eq_rounded,
                    ),
                    _StatCard(
                      label: '常听歌曲',
                      value: '${stats.uniqueTracks}',
                      icon: Icons.music_note_rounded,
                    ),
                    _StatCard(
                      label: '收藏歌曲',
                      value: '${stats.favoriteTracks}',
                      icon: Icons.favorite_rounded,
                    ),
                    _StatCard(
                      label: '歌单数量',
                      value: '${stats.playlists}',
                      icon: Icons.queue_music_rounded,
                    ),
                  ];
                  if (wide) {
                    return GridView.count(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.35,
                      children: cards,
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                },
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ErrorCard(message: '$error'),
            ),
            const SizedBox(height: 24),
            _QuickPanel(colorScheme: colorScheme),
            const SizedBox(height: 24),
            _SectionHeader(
              title: '我的收藏',
              trailing: favoritesAsync.maybeWhen(
                data: (items) => Text('${items.length} 首'),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 12),
            favoritesAsync.when(
              data: (tracks) => tracks.isEmpty
                  ? const _EmptyState(message: '还没有收藏歌曲，长按歌曲或在播放器里点心形按钮即可收藏。')
                  : _TrackSectionList(tracks: tracks),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorCard(message: '$error'),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: '自建歌单',
              trailing: TextButton(
                onPressed: () => _showCreatePlaylistDialog(context, ref),
                child: const Text('新建'),
              ),
            ),
            playlistsAsync.when(
              data: (playlists) => playlists.isEmpty
                  ? const _EmptyState(message: '还没有歌单，先新建一个吧。')
                  : Column(
                      children: playlists.map((playlist) {
                        return _PlaylistTile(
                          playlistId: playlist.id,
                          title: playlist.name,
                          trackCount: playlist.trackCount,
                          coverTrackId: playlist.coverTrackId,
                          onTap: () =>
                              PlaylistDetailSheet.show(context, playlist.id),
                          onLongPress: () => _showPlaylistMenu(
                            context,
                            ref,
                            playlist.id,
                            playlist.name,
                          ),
                        );
                      }).toList(),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorCard(message: '$error'),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: '最近播放'),
            const SizedBox(height: 12),
            historyAsync.when(
              data: (tracks) => tracks.isEmpty
                  ? const _EmptyState(message: '还没有最近播放记录。')
                  : _TrackSectionList(tracks: tracks),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorCard(message: '$error'),
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: '离线缓存'),
            const SizedBox(height: 12),
            cachedAsync.when(
              data: (tracks) => tracks.isEmpty
                  ? const _EmptyState(message: '暂时没有离线缓存歌曲。')
                  : _TrackSectionList(tracks: tracks, cachedOnly: true),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorCard(message: '$error'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入歌单名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (created != true) {
      return;
    }

    final name = controller.text.trim();
    if (name.isEmpty) {
      if (context.mounted) {
        ModernToast.show(context, '歌单名称不能为空', isError: true);
      }
      return;
    }

    try {
      await ref.read(collectionRepositoryProvider).createPlaylist(name);
      ref.invalidate(playlistsProvider);
      ref.invalidate(playStatsProvider);
      if (context.mounted) {
        ModernToast.show(context, '歌单已创建');
      }
    } catch (e) {
      if (context.mounted) {
        ModernToast.show(context, '创建歌单失败: $e', isError: true);
      }
    }
  }

  // ignore: unused_element
  Future<void> _showPlaylistDetail(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final detailAsync = ref.watch(playlistDetailProvider(playlistId));
            return detailAsync.when(
              data: (detail) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${detail.trackCount} 首歌曲'),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: detail.tracks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final track = detail.tracks[index];
                            return _TrackTile(
                              track: track,
                              onTap: () async {
                                await ref
                                    .read(playerHandlerProvider)
                                    .loadQueue(
                                      detail.tracks,
                                      startIndex: index,
                                    );
                                if (context.mounted) {
                                  context.pop();
                                  context.push('/player');
                                }
                              },
                              onLongPress: () =>
                                  TrackActionSheet.show(context, ref, track),
                              trailing: IconButton(
                                onPressed: () async {
                                  await ref
                                      .read(collectionRepositoryProvider)
                                      .removeTrackFromPlaylist(
                                        playlistId,
                                        track.id,
                                      );
                                  ref.invalidate(
                                    playlistDetailProvider(playlistId),
                                  );
                                  ref.invalidate(playlistsProvider);
                                  if (context.mounted) {
                                    ModernToast.show(context, '已从歌单移除');
                                  }
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: _ErrorCard(message: '$error'),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPlaylistMenu(
    BuildContext context,
    WidgetRef ref,
    String playlistId,
    String name,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名歌单'),
              onTap: () async {
                Navigator.of(context).pop();
                final controller = TextEditingController(text: name);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('重命名歌单'),
                    content: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: '歌单名称'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref
                      .read(collectionRepositoryProvider)
                      .renamePlaylist(playlistId, controller.text.trim());
                  ref.invalidate(playlistsProvider);
                  ref.invalidate(playlistDetailProvider(playlistId));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('删除歌单'),
              onTap: () async {
                Navigator.of(context).pop();
                await ref
                    .read(collectionRepositoryProvider)
                    .deletePlaylist(playlistId);
                ref.invalidate(playlistsProvider);
                ref.invalidate(playStatsProvider);
                if (context.mounted) {
                  ModernToast.show(context, '歌单已删除');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPanel extends StatelessWidget {
  final ColorScheme colorScheme;

  const _QuickPanel({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => context.push('/tasks'),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('任务'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.offline_bolt_rounded),
              label: const Text('缓存'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackSectionList extends ConsumerWidget {
  final List<Track> tracks;
  final bool cachedOnly;

  const _TrackSectionList({required this.tracks, this.cachedOnly = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayTracks = tracks.take(12).toList();
    return Column(
      children: displayTracks.asMap().entries.map((entry) {
        final index = entry.key;
        final track = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TrackTile(
            track: track,
            badge: cachedOnly ? '离线' : null,
            onTap: () async {
              await ref
                  .read(playerHandlerProvider)
                  .loadQueue(displayTracks, startIndex: index);
              if (context.mounted) {
                context.push('/player');
              }
            },
            onLongPress: () => TrackActionSheet.show(context, ref, track),
          ),
        );
      }).toList(),
    );
  }
}

class _TrackTile extends ConsumerWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? trailing;
  final String? badge;

  const _TrackTile({
    required this.track,
    required this.onTap,
    required this.onLongPress,
    this.trailing,
    this.badge,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final headers = auth.token == null
        ? null
        : {'Authorization': 'Bearer ${auth.token}'};
    final coverUrl =
        '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}';

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  httpHeaders: headers,
                  cacheKey: 'cover_${track.id}',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 56,
                    height: 56,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 56,
                    height: 56,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.music_note_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${track.artist} · ${track.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  IconButton(
                    onPressed: onLongPress,
                    icon: const Icon(Icons.more_horiz_rounded),
                    tooltip: '歌曲操作',
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  final String playlistId;
  final String title;
  final int trackCount;
  final String? coverTrackId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PlaylistTile({
    required this.playlistId,
    required this.title,
    required this.trackCount,
    required this.coverTrackId,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final headers = auth.token == null
        ? null
        : {'Authorization': 'Bearer ${auth.token}'};
    final coverUrl = coverTrackId == null
        ? null
        : '${auth.baseUrl}/api/tracks/$coverTrackId/cover?auth=${auth.token}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: coverUrl == null
                      ? Container(
                          width: 60,
                          height: 60,
                          color: colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.queue_music_rounded,
                            color: colorScheme.primary,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: coverUrl,
                          httpHeaders: headers,
                          cacheKey: 'cover_$coverTrackId',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            color: colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.queue_music_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$trackCount 首歌曲',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.16),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.6),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}
