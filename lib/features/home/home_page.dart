import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/track_repository.dart';
import '../../features/library/library_page.dart';
import '../library/widgets/track_edit_sheet.dart';
import '../../shared/models/track.dart';
import 'package:go_router/go_router.dart';
import 'package:audio_service/audio_service.dart';

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
                          color: Colors.white.withOpacity(0.1),
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
                const SizedBox(height: 12),

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
                const SizedBox(height: 120),
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
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
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
                    color: Colors.black.withOpacity(0.2),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04), // zinc-900/40 equivalent on a pure black background
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () =>
            ref.read(playerHandlerProvider).loadQueue(queue, startIndex: index),
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
                      color: Colors.black.withOpacity(0.2),
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
                    errorBuilder: (_, __, ___) => Container(
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
                          backgroundColor: Colors.white.withOpacity(0.1),
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
                              errorBuilder: (_, __, ___) =>
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
