import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/repositories/track_repository.dart';
import '../../shared/theme/app_theme.dart';

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
    // Note: handler is still needed for future playlist play implementation
    // final handler = ref.watch(playerHandlerProvider);
    final recommendSongsAsync = ref.watch(recommendSongsProvider);
    final recommendPlaylistsAsync = ref.watch(recommendPlaylistsProvider);

    final auth = ref.watch(authServiceProvider);
    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';

    String proxyCover(String rawUrl) =>
        '$baseUrl/api/proxy-image?url=${Uri.encodeComponent(rawUrl)}&auth=$token';

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
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
                // Header (Simplified for Discovery)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Discover',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.search,
                        size: 24,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Daily Recommendations
                _buildSectionHeader('Daily Recommendations'),
                const SizedBox(height: 16),
                recommendSongsAsync.when(
                  loading: () => const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const SizedBox(
                    height: 300,
                    child: Center(
                      child: Text('Cookie required or server error'),
                    ),
                  ),
                  data: (songs) {
                    final items = songs.take(6).toList();
                    if (items.isEmpty)
                      return const SizedBox(
                        height: 100,
                        child: Center(
                          child: Text('No recommendations available'),
                        ),
                      );
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.9,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final s = items[index];
                        return _buildAlbumCard(
                          s['title'] ?? 'Unknown',
                          s['artist'] ?? 'Unknown',
                          proxyCover(s['coverUrl'] ?? ''),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Online playback requires download task',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Recommended Playlists
                _buildSectionHeader('Discovery Playlists', showSeeAll: true),
                const SizedBox(height: 16),
                recommendPlaylistsAsync.when(
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const SizedBox(
                    height: 200,
                    child: Center(child: Text('Failed to load playlists')),
                  ),
                  data: (playlists) {
                    final items = playlists.take(6).toList();
                    return Column(
                      children: items
                          .map(
                            (p) => _buildArtistTile(
                              p['name'] ?? 'Playlist',
                              '${p['trackCount'] ?? 0} tracks',
                              proxyCover(p['coverUrl'] ?? ''),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Playlist feature coming soon',
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    bool showSeeAll = false,
    String seeAllText = 'See all',
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (showSeeAll)
          Text(
            seeAllText,
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildAlbumCard(
    String title,
    String subtitle,
    String imageUrl, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: NetworkImage(imageUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtistTile(
    String name,
    String info,
    String url, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 24, backgroundImage: NetworkImage(url)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  info,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.accent,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
