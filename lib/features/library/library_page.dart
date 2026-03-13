import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/track_repository.dart';
import '../../shared/models/track.dart';
import 'widgets/track_edit_sheet.dart';
import 'widgets/library_tools_sheet.dart';

final tracksDataProvider = FutureProvider.family<TracksResponse, String?>(
  (ref, folder) => ref.watch(trackRepositoryProvider).getTracks(folder: folder),
);

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String _activeTab = '歌曲';
  String? _selectedFolder;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String? _filterArtist;
  String? _filterAlbum;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksDataProvider(_selectedFolder));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Navigation Tabs
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: ['艺术家', '专辑', '歌曲', '文件夹'].map((tab) {
                              final isSelected = _activeTab == tab;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _activeTab = tab;
                                  if (tab != '歌曲') {
                                    _filterArtist = null;
                                    _filterAlbum = null;
                                  }
                                }),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colorScheme.primaryContainer
                                              .withValues(alpha: 0.3)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    tab,
                                    style: TextStyle(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => LibraryToolsSheet.show(context),
                        icon: Icon(
                          Icons.auto_fix_high_rounded,
                          color: colorScheme.primary,
                        ),
                        tooltip: '库管理工具',
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: tracksAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('错误: $e')),
                          data: (data) {
                            final allTracks = data.tracks;
                            var displayTracks = allTracks;

                            if (_searchQuery.isNotEmpty) {
                              final query = _searchQuery.toLowerCase();
                              displayTracks = displayTracks
                                  .where(
                                    (t) =>
                                        t.title.toLowerCase().contains(query) ||
                                        t.artist.toLowerCase().contains(
                                          query,
                                        ) ||
                                        t.album.toLowerCase().contains(query),
                                  )
                                  .toList();
                            }

                            if (_filterArtist != null) {
                              displayTracks = displayTracks
                                  .where((t) => t.artist == _filterArtist)
                                  .toList();
                            }
                            if (_filterAlbum != null) {
                              displayTracks = displayTracks
                                  .where((t) => t.album == _filterAlbum)
                                  .toList();
                            }

                            if (_activeTab == '艺术家') {
                              if (_filterArtist != null) {
                                return ListView.builder(
                                  itemCount: displayTracks.length + 1,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    100,
                                  ),
                                  itemBuilder: (context, i) {
                                    if (i == 0) {
                                      return _buildReturnTile(
                                        context,
                                        label: '返回艺术家列表',
                                        onTap: () {
                                          setState(() {
                                            _filterArtist = null;
                                          });
                                        },
                                      );
                                    }
                                    return _TrackTile(
                                      track: displayTracks[i - 1],
                                      allTracks: displayTracks,
                                      index: i - 1,
                                    );
                                  },
                                );
                              }

                              final artists = <String, List<Track>>{};
                              for (var t in displayTracks) {
                                artists.putIfAbsent(t.artist, () => []).add(t);
                              }
                              final artistList = artists.entries.toList()
                                ..sort((a, b) => a.key.compareTo(b.key));

                              return GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.85,
                                    ),
                                itemCount: artistList.length,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  100,
                                ),
                                itemBuilder: (context, i) {
                                  final artist = artistList[i].key;
                                  final count = artistList[i].value.length;
                                  final firstTrack = artistList[i].value.first;
                                  final coverUrl =
                                      '${ref.read(authServiceProvider).baseUrl ?? ''}/api/tracks/${firstTrack.id}/cover?auth=${ref.read(authServiceProvider).token ?? ''}';

                                  return GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        _filterArtist = artist;
                                        _isSearching = false;
                                      });
                                    },
                                    child: _buildGridCard(
                                      context,
                                      title: artist,
                                      subtitle: '$count 首歌曲',
                                      imageUrl: coverUrl,
                                    ),
                                  );
                                },
                              );
                            }

                            if (_activeTab == '专辑') {
                              if (_filterAlbum != null) {
                                return ListView.builder(
                                  itemCount: displayTracks.length + 1,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    100,
                                  ),
                                  itemBuilder: (context, i) {
                                    if (i == 0) {
                                      return _buildReturnTile(
                                        context,
                                        label: '返回专辑列表',
                                        onTap: () {
                                          setState(() {
                                            _filterAlbum = null;
                                          });
                                        },
                                      );
                                    }
                                    return _TrackTile(
                                      track: displayTracks[i - 1],
                                      allTracks: displayTracks,
                                      index: i - 1,
                                    );
                                  },
                                );
                              }

                              final albums = <String, List<Track>>{};
                              for (var t in displayTracks) {
                                albums.putIfAbsent(t.album, () => []).add(t);
                              }
                              final albumList = albums.entries.toList()
                                ..sort((a, b) => a.key.compareTo(b.key));

                              return GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.85,
                                    ),
                                itemCount: albumList.length,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  100,
                                ),
                                itemBuilder: (context, i) {
                                  final album = albumList[i].key;
                                  final firstTrack = albumList[i].value.first;
                                  final coverUrl =
                                      '${ref.read(authServiceProvider).baseUrl ?? ''}/api/tracks/${firstTrack.id}/cover?auth=${ref.read(authServiceProvider).token ?? ''}';

                                  return GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {
                                        _filterAlbum = album;
                                        _isSearching = false;
                                      });
                                    },
                                    child: _buildGridCard(
                                      context,
                                      title: album,
                                      subtitle: firstTrack.artist,
                                      imageUrl: coverUrl,
                                    ),
                                  );
                                },
                              );
                            }

                            if (_activeTab == '文件夹') {
                              final folders = data.folders
                                  .where(
                                    (f) => f.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ),
                                  )
                                  .toList();

                              // Use the new relativePath for precise filtering
                              final currentTracks = allTracks.where((t) {
                                final trackRelFolder = t.relativePath ?? '';
                                final requestedRelFolder =
                                    _selectedFolder ?? '';
                                return trackRelFolder.toLowerCase() ==
                                    requestedRelFolder.toLowerCase();
                              }).toList();

                              final foldersCount = folders.length;
                              final tracksCount = currentTracks.length;
                              final hasReturn = _selectedFolder != null;

                              return ListView.builder(
                                itemCount:
                                    (hasReturn ? 1 : 0) +
                                    foldersCount +
                                    tracksCount,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  100,
                                ),
                                itemBuilder: (context, i) {
                                  int index = i;

                                  if (hasReturn && index == 0) {
                                    return ListTile(
                                      leading: Icon(
                                        Icons.folder_open,
                                        color: colorScheme.primary,
                                      ),
                                      title: Text(
                                        '.. (返回上级)',
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          if (_selectedFolder!.contains('/')) {
                                            final parts = _selectedFolder!
                                                .split('/');
                                            parts.removeLast();
                                            _selectedFolder = parts.join('/');
                                          } else {
                                            _selectedFolder = null;
                                          }
                                        });
                                      },
                                    );
                                  }
                                  if (hasReturn) index--;

                                  if (index < foldersCount) {
                                    final folder = folders[index];
                                    return ListTile(
                                      leading: Icon(
                                        Icons.folder,
                                        color: colorScheme.primary,
                                      ),
                                      title: Text(
                                        folder,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _selectedFolder =
                                              _selectedFolder == null
                                              ? folder
                                              : '$_selectedFolder/$folder';
                                        });
                                      },
                                    );
                                  }
                                  index -= foldersCount;

                                  final track = currentTracks[index];
                                  return _TrackTile(
                                    track: track,
                                    allTracks: currentTracks,
                                    index: index,
                                  );
                                },
                              );
                            }

                            return ListView.builder(
                              itemCount: displayTracks.length,
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                100,
                              ),
                              itemBuilder: (context, i) => _TrackTile(
                                track: displayTracks[i],
                                allTracks: displayTracks,
                                index: i,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Floating Search Button
            Positioned(
              right: 16,
              bottom: 240,
              child: _buildFloatingSearchBar(context, colorScheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingSearchBar(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isSearching ? MediaQuery.of(context).size.width - 32 : 56,
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isSearching
          ? Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.search, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: '搜索库...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                    });
                  },
                ),
              ],
            )
          : InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () {
                setState(() {
                  _isSearching = true;
                });
              },
              child: Icon(Icons.search, color: colorScheme.primary),
            ),
    );
  }

  Widget _buildReturnTile(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.arrow_back, color: colorScheme.primary),
      title: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildGridCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String imageUrl,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => Container(
              color: colorScheme.surface,
              child: Icon(
                Icons.music_note,
                color: colorScheme.primary,
                size: 48,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.8),
                ],
                stops: const [0.4, 0.7, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends ConsumerWidget {
  final Track track;
  final List<Track> allTracks;
  final int index;
  const _TrackTile({
    required this.track,
    required this.allTracks,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: () => ref
            .read(playerHandlerProvider)
            .loadQueue(allTracks, startIndex: index),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                '${auth.baseUrl}/api/tracks/${track.id}/cover?auth=${auth.token}',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Container(
                  width: 52,
                  height: 52,
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
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          track.artist,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                    ref.invalidate(tracksDataProvider);
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
