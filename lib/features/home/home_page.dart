import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/collection_repository.dart';
import '../../core/repositories/track_repository.dart';
import '../../features/library/library_page.dart';
import '../library/widgets/track_edit_sheet.dart';
import '../my/collection_providers.dart';
import '../../shared/models/track.dart';
import '../../shared/models/playlist.dart';
import 'package:go_router/go_router.dart';
import 'package:audio_service/audio_service.dart';
import '../../shared/widgets/modern_toast.dart';
import '../../shared/widgets/track_action_sheet.dart';

final randomSongsProvider = FutureProvider.autoDispose<List<Track>>((
  ref,
) async {
  return ref.watch(trackRepositoryProvider).getRandomTracks(limit: 30);
});

final recentSongsProvider = FutureProvider.autoDispose<List<Track>>((
  ref,
) async {
  return ref.watch(trackRepositoryProvider).getRecentTracks();
});

final recommendedAlbumsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      return ref.watch(trackRepositoryProvider).getDiscoveryAlbums();
    });

final playHistoryProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  final history = await ref.watch(trackRepositoryProvider).getPlayHistory();
  // 去重：保留每个 ID 第一次出现的记录（通常是最新的）
  final seenIds = <String>{};
  return history.where((track) => seenIds.add(track.id)).toList();
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final randomAsync = ref.watch(randomSongsProvider);
    final recentAsync = ref.watch(recentSongsProvider);
    final historyAsync = ref.watch(playHistoryProvider);
    final albumsAsync = ref.watch(recommendedAlbumsProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final playlistsAsync = ref.watch(playlistsProvider);

    final auth = ref.watch(authServiceProvider);
    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(randomSongsProvider);
            ref.invalidate(recentSongsProvider);
            ref.invalidate(playHistoryProvider);
            ref.invalidate(recommendedAlbumsProvider);
            ref.invalidate(tracksDataProvider(null));
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '音乐',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    // Search Button
                    GestureDetector(
                      onTap: () => context.push('/search'),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Rotating Disc (Mini version for Header)
                    const _TopPlayingIndicator(),
                    const SizedBox(width: 4),
                    // Settings Button
                    IconButton(
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(Icons.settings_outlined),
                      iconSize: 22,
                      color: Theme.of(context).colorScheme.onSurface,
                      tooltip: '设置',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildMyLibraryEntrances(
                  context,
                  favoritesAsync,
                  playlistsAsync,
                ),
                const SizedBox(height: 24),

                // 1. Random Discovery
                _buildSectionHeader(
                  context,
                  '随机发现',
                  showSeeAll: true,
                  seeAllText: '查看全部',
                  onSeeAll: () => randomAsync.whenData(
                    (tracks) => _showTrackListPopup(context, '随机发现', tracks),
                  ),
                  // 播放全部按钮
                  actionIcon: Icons.play_circle_filled_rounded,
                  onAction: () => randomAsync.whenData((tracks) {
                    if (tracks.isNotEmpty) {
                      ref
                          .read(playerHandlerProvider)
                          .loadQueue(tracks, startIndex: 0);
                    }
                  }),
                ),
                const SizedBox(height: 10),
                randomAsync.when(
                  loading: () => const _SectionLoading(height: 160),
                  error: (e, _) => Text('错误: $e'),
                  data: (tracks) => SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: tracks.length,
                      itemBuilder: (context, index) => _buildSongCard(
                        context,
                        ref,
                        tracks[index],
                        tracks,
                        index,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Recently Added
                _buildSectionHeader(
                  context,
                  '最近添加',
                  showSeeAll: true,
                  onSeeAll: () => recentAsync.whenData(
                    (tracks) => _showTrackListPopup(context, '最近添加', tracks),
                  ),
                  actionIcon: Icons.play_circle_filled_rounded,
                  onAction: () => recentAsync.whenData((tracks) {
                    if (tracks.isNotEmpty) {
                      ref
                          .read(playerHandlerProvider)
                          .loadQueue(tracks, startIndex: 0);
                    }
                  }),
                ),
                const SizedBox(height: 10),
                recentAsync.when(
                  loading: () => const _SectionLoading(height: 160),
                  error: (e, _) => Text('错误: $e'),
                  data: (tracks) => SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: tracks.take(10).length,
                      itemBuilder: (context, index) => _buildSongCard(
                        context,
                        ref,
                        tracks[index],
                        tracks.take(10).toList(),
                        index,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Play History
                _buildSectionHeader(
                  context,
                  '播放历史',
                  showSeeAll: true,
                  onSeeAll: () => historyAsync.whenData(
                    (tracks) => _showTrackListPopup(context, '播放历史', tracks),
                  ),
                  actionIcon: Icons.play_circle_filled_rounded,
                  onAction: () => historyAsync.whenData((tracks) {
                    if (tracks.isNotEmpty) {
                      ref
                          .read(playerHandlerProvider)
                          .loadQueue(tracks, startIndex: 0);
                    }
                  }),
                ),
                const SizedBox(height: 10),
                historyAsync.when(
                  loading: () => const _SectionLoading(height: 140),
                  error: (e, _) => Text('错误: $e'),
                  data: (tracks) {
                    if (tracks.isEmpty) {
                      return const Center(
                        child: Text(
                          '暂无播放历史',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      );
                    }
                    return Column(
                      children: tracks
                          .take(10)
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (entry) => _buildTrackTile(
                              context,
                              ref,
                              entry.value,
                              tracks.take(10).toList(),
                              entry.key,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 4. Recommended Albums
                _buildSectionHeader(
                  context,
                  '探索专辑',
                  showSeeAll: true,
                  seeAllText: '换一批',
                  onSeeAll: () => ref.invalidate(recommendedAlbumsProvider),
                ),
                const SizedBox(height: 16),
                albumsAsync.when(
                  loading: () => const _SectionLoading(height: 160),
                  error: (e, _) => Text('错误: $e'),
                  data: (albums) => SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        final albumName = album['album'] as String;
                        return _buildAlbumCard(
                          context,
                          albumName,
                          album['artist'] as String,
                          '$baseUrl/api/tracks/${album['id']}/cover?auth=$token',
                          onTap: () async {
                            final allTracksData = await ref.read(
                              tracksDataProvider(null).future,
                            );
                            final albumTracks = allTracksData.tracks
                                .where((t) => t.album == albumName)
                                .toList();
                            if (!context.mounted) return;
                            _showAlbumDetails(
                              context,
                              ref,
                              albumName,
                              albumTracks,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyLibraryEntrances(
    BuildContext context,
    AsyncValue<List<Track>> favoritesAsync,
    AsyncValue<List<UserPlaylist>> playlistsAsync,
  ) {
    return SizedBox(
      height: 92,
      child: Row(
        children: [
          Expanded(
            child: _buildLibraryEntryChip(
              context,
              icon: Icons.favorite_rounded,
              label: '收藏',
              countText: favoritesAsync.maybeWhen(
                data: (tracks) => '${tracks.length}',
                loading: () => '...',
                orElse: () => '--',
              ),
              accentColor: Colors.pinkAccent,
              onTap: () => favoritesAsync.whenData(
                (tracks) => _showFavoritesSheet(context, tracks),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildLibraryEntryChip(
              context,
              icon: Icons.queue_music_rounded,
              label: '歌单',
              countText: playlistsAsync.maybeWhen(
                data: (playlists) => '${playlists.length}',
                loading: () => '...',
                orElse: () => '--',
              ),
              accentColor: Colors.lightBlueAccent,
              onTap: () => playlistsAsync.whenData(
                (playlists) => _showPlaylistsSheet(context, playlists),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryEntryChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String countText,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countText,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    bool showSeeAll = false,
    String seeAllText = '查看全部',
    VoidCallback? onSeeAll,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (actionIcon != null && onAction != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: colorScheme.onPrimary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (showSeeAll)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              seeAllText,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  void _showFavoritesSheet(BuildContext context, List<Track> tracks) {
    _showTrackListPopup(context, '我的收藏', tracks);
  }

  void _showPlaylistsSheet(
    BuildContext context,
    List<UserPlaylist> playlists,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '我的歌单',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showCreatePlaylistDialog(this.context);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('新建'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '还没有歌单，先建一个吧。',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.16,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.queue_music_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                          title: Text(playlist.name),
                          subtitle: Text('${playlist.trackCount} 首歌曲'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).pop();
                            _showPlaylistDetail(this.context, playlist.id);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreatePlaylistDialog(BuildContext context) async {
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

  void _showPlaylistDetail(BuildContext context, String playlistId) {
    showModalBottomSheet<void>(
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
                            return _buildTrackTile(
                              context,
                              ref,
                              track,
                              detail.tracks,
                              index,
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
                child: Text('加载失败: $error'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSongCard(
    BuildContext context,
    WidgetRef ref,
    Track track,
    List<Track> queue,
    int index,
  ) {
    final auth = ref.read(authServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () =>
          ref.read(playerHandlerProvider).loadQueue(queue, startIndex: index),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl:
                      '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                  cacheKey: 'cover_${track.id}',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: 100,
                    height: 100,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.music_note, color: colorScheme.primary, size: 30),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8), 
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFB3B3B3),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumCard(
    BuildContext context,
    String name,
    String artist,
    String url, {
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(url),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFB3B3B3),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrackListPopup(
    BuildContext context,
    String title,
    List<Track> tracks,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: Container(
          width: size.width * 0.9,
          height: size.height * 0.8,
          margin: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () {
                        ref
                            .read(playerHandlerProvider)
                            .loadQueue(tracks, startIndex: 0);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 30),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) => _buildTrackTile(
                    context,
                    ref,
                    tracks[index],
                    tracks,
                    index,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlbumDetails(
    BuildContext context,
    WidgetRef ref,
    String albumName,
    List<Track> tracks,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Center(
        child: Container(
          width: size.width * 0.9,
          height: size.height * 0.75,
          margin: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            albumName,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${tracks.length} 首歌曲 · ${tracks.isNotEmpty ? tracks.first.artist : ""}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () {
                        ref
                            .read(playerHandlerProvider)
                            .loadQueue(tracks, startIndex: 0);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 30),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) => _buildTrackTile(
                    context,
                    ref,
                    tracks[index],
                    tracks,
                    index,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackTile(
    BuildContext context,
    WidgetRef ref,
    Track track,
    List<Track> queue,
    int index,
  ) {
    final auth = ref.read(authServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04), // zinc-900/40 equivalent on a pure black background
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () =>
            ref.read(playerHandlerProvider).loadQueue(queue, startIndex: index),
        onLongPress: () => TrackActionSheet.show(context, ref, track),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 56,
                      height: 56,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.music_note,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            track.artist,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (track.extension.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              track.extension.toUpperCase().replaceAll('.', ''),
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          track.sizeText,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {
                  TrackEditSheet.show(
                    context,
                    track,
                    onSaved: () {
                      ref.invalidate(recentSongsProvider);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  final double height;
  const _SectionLoading({required this.height});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _TopPlayingIndicator extends ConsumerStatefulWidget {
  const _TopPlayingIndicator();

  @override
  ConsumerState<_TopPlayingIndicator> createState() => _TopPlayingIndicatorState();
}

class _TopPlayingIndicatorState extends ConsumerState<_TopPlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: ref.watch(playerHandlerProvider).mediaItem,
      builder: (context, snapshot) {
        final item = snapshot.data;
        if (item == null) return const SizedBox.shrink();

        return StreamBuilder<bool>(
          stream: ref.watch(playerHandlerProvider).playbackState.map((state) => state.playing),
          builder: (context, playingSnap) {
            final isPlaying = playingSnap.data ?? false;
            if (isPlaying && !_rotationController.isAnimating) {
              _rotationController.repeat();
            } else if (!isPlaying && _rotationController.isAnimating) {
              _rotationController.stop();
            }

            return StreamBuilder<Duration>(
              stream: AudioService.position,
              builder: (context, posSnap) {
                final position = posSnap.data ?? Duration.zero;
                final duration = item.duration ?? Duration.zero;
                final progress = duration.inMilliseconds > 0
                    ? position.inMilliseconds / duration.inMilliseconds
                    : 0.0;

                return GestureDetector(
                  onTap: () => context.push('/player'),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(40, 40),
                        painter: _TopCircularProgressPainter(
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
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child: Image.network(
                              '${item.artUri}',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.music_note, size: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TopCircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _TopCircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 2.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

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
  bool shouldRepaint(covariant _TopCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
