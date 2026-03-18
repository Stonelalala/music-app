import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/track_repository.dart';
import '../../shared/models/network_track.dart';
import '../../shared/models/track.dart';
import '../../shared/widgets/mini_player.dart';
import '../../shared/widgets/track_action_sheet.dart';
import '../library/library_page.dart';
import 'network_search_provider.dart';
import 'search_history_provider.dart';

enum SearchScope { local, all, network }

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchCategoryProvider = StateProvider<String>((ref) => 'songs');
final searchScopeProvider = StateProvider<SearchScope>(
  (ref) => SearchScope.local,
);

final filteredTracksProvider = Provider<List<Track>>((ref) {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final tracksAsync = ref.watch(tracksDataProvider(null));

  return tracksAsync.maybeWhen(
    data: (data) {
      if (query.isEmpty) {
        return const <Track>[];
      }
      return data.tracks.where((track) {
        return track.title.toLowerCase().contains(query) ||
            track.artist.toLowerCase().contains(query) ||
            track.album.toLowerCase().contains(query);
      }).toList();
    },
    orElse: () => const <Track>[],
  );
});

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialScope = SearchScope.local});

  final SearchScope initialScope;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchScopeProvider.notifier).state = widget.initialScope;
      ref.read(networkSearchQueryProvider.notifier).state = ref.read(
        searchQueryProvider,
      );
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateQuery(String value, {bool remember = false}) {
    final query = value.trim();
    ref.read(searchQueryProvider.notifier).state = query;
    ref.read(networkSearchQueryProvider.notifier).state = query;
    if (remember && query.isNotEmpty) {
      ref.read(searchHistoryProvider.notifier).addQuery(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final scope = ref.watch(searchScopeProvider);
    final category = ref.watch(searchCategoryProvider);
    final history = ref.watch(searchHistoryProvider);
    final localResults = ref.watch(filteredTracksProvider);
    final networkResults = ref.watch(networkSearchResultsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
      body: ColoredBox(
        color: colorScheme.surface,
        child: SafeArea(
          child: Column(
            children: [
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
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          textAlignVertical: TextAlignVertical.center,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            hintText: '搜索本地和全网音乐',
                            hintStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      _updateQuery('');
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            _updateQuery(value);
                            setState(() {});
                          },
                          onSubmitted: (value) =>
                              _updateQuery(value, remember: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildScopeBar(scope),
              if (query.isNotEmpty && scope != SearchScope.local)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildNetworkSourceBar(),
                ),
              if (query.isNotEmpty && scope != SearchScope.network)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildLocalCategoryBar(category),
                ),
              Expanded(
                child: query.isEmpty
                    ? _buildSearchHistory(history)
                    : _buildResultsBody(
                        scope: scope,
                        category: category,
                        localResults: localResults,
                        networkResults: networkResults,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeBar(SearchScope scope) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _ScopeChip(
            label: '本地',
            selected: scope == SearchScope.local,
            onTap: () => ref.read(searchScopeProvider.notifier).state =
                SearchScope.local,
          ),
          _ScopeChip(
            label: '全部',
            selected: scope == SearchScope.all,
            onTap: () =>
                ref.read(searchScopeProvider.notifier).state = SearchScope.all,
          ),
          _ScopeChip(
            label: '全网',
            selected: scope == SearchScope.network,
            onTap: () => ref.read(searchScopeProvider.notifier).state =
                SearchScope.network,
          ),
        ],
      ),
    );
  }

  Widget _buildLocalCategoryBar(String category) {
    final items = const <(String key, String label)>[
      ('songs', '歌曲'),
      ('albums', '专辑'),
      ('artists', '艺术家'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items.map((item) {
          final isSelected = category == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(item.$2),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) {
                ref.read(searchCategoryProvider.notifier).state = item.$1;
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNetworkSourceBar() {
    final source = ref.watch(networkSearchSourceProvider);
    const sources = <(String key, String label)>[
      ('netease', '网易云'),
      ('qq', 'QQ 音乐'),
      ('kugou', '酷狗'),
      ('kuwo', '酷我'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: sources.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(item.$2),
              selected: source == item.$1,
              showCheckmark: false,
              onSelected: (_) {
                ref.read(networkSearchSourceProvider.notifier).state = item.$1;
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchHistory(List<String> history) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (history.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '搜索历史',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(searchHistoryProvider.notifier)
                          .clearHistory(),
                      child: const Text('清空'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: history.map((item) {
                    return ActionChip(
                      avatar: Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      label: Text(item),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.18,
                        ),
                      ),
                      backgroundColor: colorScheme.surface.withValues(
                        alpha: 0.52,
                      ),
                      onPressed: () {
                        _searchController.text = item;
                        _updateQuery(item, remember: true);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.72,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  '还没有搜索历史',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsBody({
    required SearchScope scope,
    required String category,
    required List<Track> localResults,
    required AsyncValue<List<NetworkTrack>> networkResults,
  }) {
    return switch (scope) {
      SearchScope.local => _buildLocalResults(category, localResults),
      SearchScope.network => _buildNetworkResults(networkResults),
      SearchScope.all => _buildAllResults(localResults, networkResults),
    };
  }

  Widget _buildLocalResults(String category, List<Track> results) {
    final colorScheme = Theme.of(context).colorScheme;

    if (results.isEmpty) {
      return Center(
        child: Text(
          '没有匹配的本地结果',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    if (category == 'songs') {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        itemCount: results.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildPlayAllHeader(results);
          }
          final track = results[index - 1];
          return _buildTrackTile(track, results, index - 1);
        },
      );
    }

    if (category == 'albums') {
      final albums = <String, List<Track>>{};
      for (final track in results) {
        albums.putIfAbsent(track.album, () => <Track>[]).add(track);
      }
      final entries = albums.entries.toList();
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _buildAlbumTile(entry.key, entry.value);
        },
      );
    }

    final artists = <String, List<Track>>{};
    for (final track in results) {
      artists.putIfAbsent(track.artist, () => <Track>[]).add(track);
    }
    final entries = artists.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildArtistTile(entry.key, entry.value);
      },
    );
  }

  Widget _buildNetworkResults(AsyncValue<List<NetworkTrack>> networkResults) {
    return networkResults.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('搜索失败: $error')),
      data: (results) {
        if (results.isEmpty) {
          return const Center(child: Text('没有匹配的全网结果'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: results.length,
          separatorBuilder: (context, index) => const SizedBox(height: 0),
          itemBuilder: (context, index) => _buildNetworkTile(results[index]),
        );
      },
    );
  }

  Widget _buildAllResults(
    List<Track> localResults,
    AsyncValue<List<NetworkTrack>> networkResults,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildResultSectionTitle(
          '本地结果',
          trailing: localResults.isEmpty ? '0' : '${localResults.length}',
        ),
        const SizedBox(height: 8),
        if (localResults.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text('没有匹配的本地结果'),
          )
        else ...[
          ...localResults
              .take(8)
              .toList()
              .asMap()
              .entries
              .map(
                (entry) =>
                    _buildTrackTile(entry.value, localResults, entry.key),
              ),
          if (localResults.length > 8)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ref.read(searchScopeProvider.notifier).state =
                      SearchScope.local;
                },
                child: const Text('查看全部本地结果'),
              ),
            ),
        ],
        const SizedBox(height: 18),
        _buildResultSectionTitle('全网结果'),
        const SizedBox(height: 8),
        networkResults.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('搜索失败: $error'),
          data: (results) {
            if (results.isEmpty) {
              return const Text('没有匹配的全网结果');
            }
            return Column(
              children: results.take(10).map(_buildNetworkTile).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildResultSectionTitle(String title, {String? trailing}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildPlayAllHeader(List<Track> tracks) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surfaceContainerHigh.withValues(alpha: 0.96),
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.82),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
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
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  ref
                      .read(playerHandlerProvider)
                      .loadQueue(tracks, startIndex: 0);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                color: colorScheme.onPrimary,
                iconSize: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '播放全部',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tracks.length} 首结果，直接从第一首开始播放',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
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

  Widget _buildTrackTile(Track track, List<Track> queue, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.read(authServiceProvider);

    return InkWell(
      onTap: () =>
          ref.read(playerHandlerProvider).loadQueue(queue, startIndex: index),
      onLongPress: () => TrackActionSheet.show(context, ref, track),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                width: 62,
                height: 62,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Container(
                  width: 62,
                  height: 62,
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
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${track.artist} / ${track.extension.replaceAll('.', '').toUpperCase()} / ${track.sizeText}',
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.more_horiz_rounded, size: 18),
                onPressed: () => TrackActionSheet.show(context, ref, track),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumTile(String album, List<Track> tracks) {
    final colorScheme = Theme.of(context).colorScheme;
    final auth = ref.read(authServiceProvider);
    final firstTrack = tracks.first;

    return InkWell(
      onTap: () {
        ref.read(playerHandlerProvider).loadQueue(tracks, startIndex: 0);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                '${auth.baseUrl}/api/tracks/${firstTrack.id}/cover?auth=${auth.token}',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Container(
                  width: 60,
                  height: 60,
                  color: colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tracks.length} 首歌曲 / ${firstTrack.artist}',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_fill_rounded,
              color: colorScheme.primary,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistTile(String artist, List<Track> tracks) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        ref.read(playerHandlerProvider).loadQueue(tracks, startIndex: 0);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer.withValues(
                alpha: 0.7,
              ),
              child: Text(
                artist.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${tracks.length} 首歌曲',
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

  Widget _buildNetworkTile(NetworkTrack track) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: track.coverUrl != null
                ? Image.network(
                    track.coverUrl!,
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) =>
                        _buildFallbackCover(colorScheme),
                  )
                : _buildFallbackCover(colorScheme),
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
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${track.artist} / ${track.album}${track.year == null ? '' : ' / ${track.year}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => _showDownloadOptions(track),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.download_rounded,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCover(ColorScheme colorScheme) {
    return Container(
      width: 58,
      height: 58,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note_rounded, color: colorScheme.primary),
    );
  }

  Future<void> _handleDownload(NetworkTrack track, String level) async {
    final repo = ref.read(trackRepositoryProvider);
    try {
      if (track.source == 'qq') {
        await repo.downloadQQMusicSong(track.id, level);
      } else if (track.source == 'kugou') {
        await repo.downloadKugouSong(track.id, level);
      } else if (track.source == 'kuwo') {
        await repo.downloadKuwoSong(track.id, level);
      } else {
        await repo.downloadNeteaseSong(track.id, level);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已下发下载任务: ${track.title}')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败: $error')));
      }
    }
  }

  void _showDownloadOptions(NetworkTrack track) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('标准音质'),
              onTap: () {
                Navigator.of(context).pop();
                _handleDownload(track, 'standard');
              },
            ),
            ListTile(
              title: const Text('极高音质 (320k)'),
              onTap: () {
                Navigator.of(context).pop();
                _handleDownload(track, 'exhigh');
              },
            ),
            ListTile(
              title: const Text('无损音质'),
              onTap: () {
                Navigator.of(context).pop();
                _handleDownload(track, 'lossless');
              },
            ),
            ListTile(
              title: const Text('Hi-Res'),
              onTap: () {
                Navigator.of(context).pop();
                _handleDownload(track, 'hires');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.26)
              : colorScheme.outlineVariant.withValues(alpha: 0.16),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.18,
        ),
        selectedColor: colorScheme.primary.withValues(alpha: 0.14),
        labelStyle: TextStyle(
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
