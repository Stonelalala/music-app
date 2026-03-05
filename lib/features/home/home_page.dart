import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/track_repository.dart';
import '../../features/library/library_page.dart';
import '../library/widgets/track_edit_sheet.dart';
import '../../shared/models/track.dart';

final randomSongsProvider = FutureProvider.autoDispose<List<Track>>((
  ref,
) async {
  return ref.watch(trackRepositoryProvider).getRandomTracks();
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
    final albumsAsync = ref.watch(recommendedAlbumsProvider);
    final allTracksAsync = ref.watch(tracksDataProvider(null));

    final auth = ref.watch(authServiceProvider);
    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(randomSongsProvider);
            ref.invalidate(recentSongsProvider);
            ref.invalidate(recommendedAlbumsProvider);
            ref.invalidate(tracksDataProvider(null));
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

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
                const SizedBox(height: 16),
                randomAsync.when(
                  loading: () => const _SectionLoading(height: 140),
                  error: (e, _) => Text('错误: $e'),
                  data: (tracks) => SizedBox(
                    height: 140,
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
                const SizedBox(height: 32),

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
                const SizedBox(height: 16),
                recentAsync.when(
                  loading: () => const _SectionLoading(height: 140),
                  error: (e, _) => Text('错误: $e'),
                  data: (tracks) => SizedBox(
                    height: 140,
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
                const SizedBox(height: 32),

                // 3. Most Played (Simulation from all tracks)
                _buildSectionHeader(context, '播放最多', showSeeAll: false),
                const SizedBox(height: 16),
                allTracksAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('错误: $e'),
                  data: (data) {
                    final mostPlayed = data.tracks.length > 5
                        ? data.tracks
                              .sublist(data.tracks.length - 5)
                              .reversed
                              .toList()
                        : data.tracks;
                    return Column(
                      children: mostPlayed
                          .asMap()
                          .entries
                          .map(
                            (entry) => _buildTrackTile(
                              context,
                              ref,
                              entry.value,
                              mostPlayed,
                              entry.key,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),

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
                  loading: () => const _SectionLoading(height: 195),
                  error: (e, _) => Text('错误: $e'),
                  data: (albums) => SizedBox(
                    height: 195,
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
                            if (mounted)
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
                const SizedBox(height: 150),
              ],
            ),
          ),
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
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actionIcon != null && onAction != null)
              IconButton(
                icon: Icon(actionIcon, color: colorScheme.primary, size: 28),
                onPressed: onAction,
                tooltip: '播放全部',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
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
        width: 110,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 110,
                  height: 110,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.music_note, color: colorScheme.primary),
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
        width: 130,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: NetworkImage(url),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
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
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
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
                  color: colorScheme.onSurfaceVariant.withOpacity(0.3),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () =>
            ref.read(playerHandlerProvider).loadQueue(queue, startIndex: index),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.music_note,
                    color: colorScheme.primary,
                    size: 20,
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
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        track.artist,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (track.extension.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.15),
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
                          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
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
