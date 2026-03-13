import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../shared/models/track.dart';
import '../library/library_page.dart';
import '../library/widgets/track_edit_sheet.dart';
import 'search_history_provider.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchCategoryProvider = StateProvider<String>((ref) => '歌曲');

final filteredTracksProvider = Provider<List<Track>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final tracksAsync = ref.watch(tracksDataProvider(null));
  
  return tracksAsync.maybeWhen(
    data: (data) {
      if (query.isEmpty) return [];
      return data.tracks.where((t) =>
        t.title.toLowerCase().contains(query) ||
        t.artist.toLowerCase().contains(query) ||
        t.album.toLowerCase().contains(query)
      ).toList();
    },
    orElse: () => [],
  );
});

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(searchQueryProvider);
    // 自动聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    if (value.trim().isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).addQuery(value.trim());
    }
    ref.read(searchQueryProvider.notifier).state = value;
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final history = ref.watch(searchHistoryProvider);
    final category = ref.watch(searchCategoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText: '搜索歌曲、专辑或艺术家',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearch('');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) => setState(() {}),
                        onSubmitted: _onSearch,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.cloud_download_outlined),
                    tooltip: '全网搜歌',
                    onPressed: () => context.push('/network-search'),
                  ),
                ],
              ),
            ),

            if (query.isEmpty) ...[
              // Search History
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (history.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '搜索历史',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          TextButton(
                            onPressed: () => ref.read(searchHistoryProvider.notifier).clearHistory(),
                            child: const Text('管理'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: history.map((q) => ActionChip(
                          label: Text(q),
                          onPressed: () {
                            _searchController.text = q;
                            _onSearch(q);
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              // Results Filters
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['歌曲', '专辑', '艺术家'].map((cat) {
                      final isSelected = category == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) ref.read(searchCategoryProvider.notifier).state = cat;
                          },
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Results List
              Expanded(
                child: _buildResults(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    final category = ref.watch(searchCategoryProvider);
    final results = ref.watch(filteredTracksProvider);
    final colorScheme = Theme.of(context).colorScheme;

    if (results.isEmpty) {
      return Center(
        child: Text(
          '没有匹配的结果',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    if (category == '歌曲') {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 40),
        itemCount: results.length + 2, // +Header +Footer
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildPlayAllHeader(results);
          }
          if (index == results.length + 1) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '没有更多了',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            );
          }
          final track = results[index - 1];
          return _buildTrackTile(context, track, results, index - 1);
        },
      );
    } else if (category == '专辑') {
      final albumsMap = <String, List<Track>>{};
      for (var t in results) {
        albumsMap.putIfAbsent(t.album, () => []).add(t);
      }
      final albumList = albumsMap.keys.toList();

      return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: albumList.length,
          itemBuilder: (context, index) {
            final album = albumList[index];
            final tracks = albumsMap[album]!;
            return _buildAlbumTile(context, album, tracks);
          });
    } else {
      // 艺术家
      final artistsMap = <String, List<Track>>{};
      for (var t in results) {
        artistsMap.putIfAbsent(t.artist, () => []).add(t);
      }
      final artistList = artistsMap.keys.toList();

      return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: artistList.length,
          itemBuilder: (context, index) {
            final artist = artistList[index];
            final tracks = artistsMap[artist]!;
            return _buildArtistTile(context, artist, tracks);
          });
    }
  }

  Widget _buildPlayAllHeader(List<Track> tracks) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: () {
              ref.read(playerHandlerProvider).loadQueue(tracks, startIndex: 0);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            iconSize: 24,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '播放全部 (${tracks.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.list_rounded),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(BuildContext context, Track track, List<Track> queue, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.read(authServiceProvider);
    
    return InkWell(
      onTap: () => ref.read(playerHandlerProvider).loadQueue(queue, startIndex: index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Container(
                  width: 56,
                  height: 56,
                  color: colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.music_note, color: colorScheme.primary),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${track.artist} · ${track.extension.replaceAll('.', '').toUpperCase()} · ${track.sizeText}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border_rounded, size: 20),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onPressed: () {
                 TrackEditSheet.show(context, track, onSaved: () {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumTile(BuildContext context, String album, List<Track> tracks) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.read(authServiceProvider);
    final firstTrack = tracks.first;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          '${auth.baseUrl}/api/tracks/${firstTrack.id}/cover?auth=${auth.token}',
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => Container(
            width: 50,
            height: 50,
            color: colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
      title: Text(album, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${tracks.length} 首歌曲 · ${firstTrack.artist}'),
      onTap: () {
        // TODO: 可选实现展示专辑内歌曲
        ref.read(playerHandlerProvider).loadQueue(tracks, startIndex: 0);
      },
    );
  }

  Widget _buildArtistTile(BuildContext context, String artist, List<Track> tracks) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: CircleAvatar(
        radius: 25,
        backgroundColor: colorScheme.primaryContainer,
        child: Text(artist.substring(0, 1).toUpperCase()),
      ),
      title: Text(artist, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${tracks.length} 首歌曲'),
      onTap: () {
        ref.read(playerHandlerProvider).loadQueue(tracks, startIndex: 0);
      },
    );
  }
}
