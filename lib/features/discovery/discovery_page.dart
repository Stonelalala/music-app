import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:music/core/auth/auth_service.dart';
import 'package:music/core/repositories/track_repository.dart';
import 'package:music/shared/theme/app_theme.dart';
import 'package:music/shared/widgets/modern_toast.dart';
import 'widgets/music_downloader_sheet.dart';
import 'widgets/playlist_detail_sheet.dart';

final recommendSongsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(trackRepositoryProvider).getRecommendSongs();
});

final recommendPlaylistsProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(trackRepositoryProvider).getRecommendPlaylists();
});

class DiscoveryPage extends ConsumerWidget {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendSongsAsync = ref.watch(recommendSongsProvider);
    final recommendPlaylistsAsync = ref.watch(recommendPlaylistsProvider);
    final themeType = ref.watch(themeTypeProvider);

    final auth = ref.watch(authServiceProvider);
    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';

    String proxyCover(String rawUrl) =>
        '$baseUrl/api/proxy-image?url=${Uri.encodeComponent(rawUrl)}&auth=$token';

    Future<void> quickDownload(String id, String title) async {
      try {
        await ref
            .read(trackRepositoryProvider)
            .downloadNeteaseSong(id, 'exhigh');
        if (context.mounted) {
          ModernToast.show(
            context,
            '已加入下载队列: $title',
            icon: Icons.download_done,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ModernToast.show(context, '下载失败: $e', isError: true);
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recommendSongsProvider);
            ref.invalidate(recommendPlaylistsProvider);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(context, ref, themeType),
                const SizedBox(height: 16),

                // 1. Daily Recommendations
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '每日推荐',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                recommendSongsAsync.when(
                  loading: () => _buildLoadingShimmer(height: 160),
                  error: (e, _) => _buildErrorState('无法加载推荐'),
                  data: (songs) {
                    return _buildDailyBanner(
                      context,
                      songs,
                      proxyCover,
                      quickDownload,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 3. Recommended Playlists
                _buildSectionHeader(
                  context,
                  '推荐歌单',
                  onSeeAll: () {
                    recommendPlaylistsAsync.whenData((playlists) {
                      _showPlaylistsGridPopup(
                        context,
                        '全部推荐歌单',
                        playlists,
                        proxyCover,
                      );
                    });
                  },
                ),
                recommendPlaylistsAsync.when(
                  loading: () => _buildLoadingShimmer(height: 480),
                  error: (e, _) => _buildErrorState('无法加载歌单'),
                  data: (playlists) {
                    final items = playlists.take(6).toList();
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 160,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final p = items[index];
                        return _buildCompactPlaylistCard(
                          context,
                          p,
                          proxyCover(p['coverUrl'] ?? ''),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),

                // 2. Music Downloader Entry (Moved to Bottom)
                _buildDownloaderBanner(context),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyBanner(
    BuildContext context,
    List<dynamic> songs,
    String Function(String) proxy,
    Function(String, String) onDownload,
  ) {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = _getMonthName(now.month);

    return GestureDetector(
      onTap: () => _showTracksGridPopup(
        context,
        '每日 30 首 (Songs)',
        songs,
        proxy,
        onDownload,
      ),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE91E63), Color(0xFFFF9800)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E63).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.music_note_rounded,
                size: 150,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Date Card
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          month,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '每日 30 首 (Songs)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '基于您的听歌喜好，为您定制的 30 首每日惊喜。',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            '30 首歌曲',
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ],
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

  String _getMonthName(int month) {
    const names = [
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月',
    ];
    return names[month - 1];
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ThemeType currentTheme,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE91E63),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.explore_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            '发现与推荐',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: () {
            ref.invalidate(recommendSongsProvider);
            ref.invalidate(recommendPlaylistsProvider);
            ModernToast.show(context, '已刷新推荐内容', icon: Icons.refresh_rounded);
          },
          icon: Icon(Icons.refresh_rounded, color: colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    VoidCallback? onSeeAll,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            '查看全部',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloaderBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => MusicDownloaderSheet.show(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '万能解析下载',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '快捷网易/QQ入库',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 32),
          ],
        ),
      ),
    );
  }

  void _showTracksGridPopup(
    BuildContext context,
    String title,
    List<dynamic> tracks,
    String Function(String) proxy,
    Function(String, String) onDownload,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GridPopup(
        title: title,
        itemCount: tracks.length,
        isGrid: false,
        itemBuilder: (ctx, index) {
          final s = tracks[index];
          return _buildTrackListTile(
            context,
            s,
            proxy(s['coverUrl'] ?? ''),
            () => onDownload(s['id'].toString(), s['title'] ?? '歌曲'),
          );
        },
      ),
    );
  }

  Widget _buildTrackListTile(
    BuildContext context,
    Map<String, dynamic> song,
    String imageUrl,
    VoidCallback onDownload,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.music_note, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song['title'] ?? '未知',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  song['artist'] ?? '未知',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPlaylistCard(
    BuildContext context,
    Map<String, dynamic> playlist,
    String imageUrl,
  ) {
    return GestureDetector(
      onTap: () => PlaylistDetailSheet.show(context, playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.playlist_play),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            playlist['name'] ?? '歌单',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showPlaylistsGridPopup(
    BuildContext context,
    String title,
    List<dynamic> playlists,
    String Function(String) proxy,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GridPopup(
        title: title,
        itemCount: playlists.length,
        isGrid: true,
        itemBuilder: (ctx, index) {
          final p = playlists[index];
          return _buildCompactPlaylistCard(
            context,
            p,
            proxy(p['coverUrl'] ?? ''),
          );
        },
      ),
    );
  }

  Widget _buildLoadingShimmer({double height = 200}) => SizedBox(
    height: height,
    child: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildErrorState(String msg) =>
      SizedBox(height: 100, child: Center(child: Text(msg)));
}

class _GridPopup extends StatelessWidget {
  final String title;
  final int itemCount;
  final bool isGrid;
  final Widget Function(BuildContext, int) itemBuilder;

  const _GridPopup({
    required this.title,
    required this.itemCount,
    this.isGrid = true,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (!isGrid) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '精选内容',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ModernToast.show(context, '正在解析并下载全部歌曲...');
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text(
                          '全部下载',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 32),
              Expanded(
                child: isGrid
                    ? GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              mainAxisExtent: 200,
                            ),
                        itemCount: itemCount,
                        itemBuilder: itemBuilder,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: itemCount,
                        itemBuilder: itemBuilder,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
