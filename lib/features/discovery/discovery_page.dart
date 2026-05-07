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
                const SizedBox(height: 12),
                _buildHeader(context, ref, themeType),
                const SizedBox(height: 18),

                _buildSectionHeader(context, '每日推荐'),
                const SizedBox(height: 14),
                recommendSongsAsync.when(
                  loading: () => _buildLoadingShimmer(height: 176),
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
                            mainAxisExtent: 154,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = _getMonthName(now.month);

    return GestureDetector(
      onTap: () =>
          _showTracksGridPopup(context, '每日 30 首', songs, proxy, onDownload),
      child: Container(
        width: double.infinity,
        height: 134,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
              colorScheme.surfaceContainer.withValues(alpha: 0.92),
              colorScheme.primary.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Icon(
                Icons.multitrack_audio_rounded,
                size: 56,
                color: colorScheme.primary.withValues(alpha: 0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 68,
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.54),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.16,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          month,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '今日推荐',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '每日 30 首',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: colorScheme.onPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${songs.length} 首',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient(colorScheme),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.explore_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '发现',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
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
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? subtitle,
    VoidCallback? onSeeAll,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton.icon(
              onPressed: onSeeAll,
              icon: Icon(
                Icons.grid_view_rounded,
                size: 14,
                color: colorScheme.primary,
              ),
              label: Text(
                '查看全部',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloaderBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => MusicDownloaderSheet.show(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
              colorScheme.primary.withValues(alpha: 0.14),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '万能解析下载',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '快速把网易云、QQ 音乐内容收进本地库',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.rocket_launch_rounded,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => PlaylistDetailSheet.show(context, playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.14),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.36,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.playlist_play_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            playlist['name'] ?? '歌单',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.84),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
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
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ModernToast.show(context, '正在解析并下载全部歌曲...');
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
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
