import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_service.dart';
import '../../core/player/player_service.dart';
import '../../core/repositories/track_repository.dart';
import '../../shared/models/track.dart';
import '../../shared/theme/app_theme.dart';

final tracksDataProvider = FutureProvider.family<TracksResponse, String?>(
  (ref, folder) => ref.watch(trackRepositoryProvider).getTracks(folder: folder),
);

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  String _activeTab = 'Songs';
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

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Navigation Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: ['Artists', 'Albums', 'Songs', 'Folders'].map((
                        tab,
                      ) {
                        final isSelected = _activeTab == tab;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _activeTab = tab;
                            if (tab != 'Songs') {
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
                                  ? AppTheme.surfaceElevated
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tab,
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.accent
                                    : AppTheme.textSecondary,
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

                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: tracksAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('Error: $e')),
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

                            if (_activeTab == 'Artists') {
                              if (_filterArtist != null) {
                                final artistTracks = displayTracks
                                    .where((t) => t.artist == _filterArtist)
                                    .toList();
                                return ListView.builder(
                                  itemCount: artistTracks.length + 1,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    100,
                                  ),
                                  itemBuilder: (context, i) {
                                    if (i == 0) {
                                      return _buildReturnTile(
                                        label: 'Return to Artists',
                                        onTap: () {
                                          setState(() {
                                            _filterArtist = null;
                                          });
                                        },
                                      );
                                    }
                                    return _TrackTile(
                                      track: artistTracks[i - 1],
                                      allTracks: artistTracks,
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
                                      title: artist,
                                      subtitle: '$count songs',
                                      imageUrl: coverUrl,
                                    ),
                                  );
                                },
                              );
                            }

                            if (_activeTab == 'Albums') {
                              if (_filterAlbum != null) {
                                final albumTracks = displayTracks
                                    .where((t) => t.album == _filterAlbum)
                                    .toList();
                                return ListView.builder(
                                  itemCount: albumTracks.length + 1,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    100,
                                  ),
                                  itemBuilder: (context, i) {
                                    if (i == 0) {
                                      return _buildReturnTile(
                                        label: 'Return to Albums',
                                        onTap: () {
                                          setState(() {
                                            _filterAlbum = null;
                                          });
                                        },
                                      );
                                    }
                                    return _TrackTile(
                                      track: albumTracks[i - 1],
                                      allTracks: albumTracks,
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
                                  final count = albumList[i].value.length;
                                  final firstTrack = albumList[i].value.first;
                                  final artistName = firstTrack.artist;
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
                                      title: album,
                                      subtitle: artistName,
                                      imageUrl: coverUrl,
                                    ),
                                  );
                                },
                              );
                            }

                            if (_activeTab == 'Folders') {
                              final folders = data.folders
                                  .where(
                                    (f) => f.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ),
                                  )
                                  .toList();
                              return ListView.builder(
                                itemCount:
                                    folders.length +
                                    (_selectedFolder != null ? 1 : 0),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  100,
                                ),
                                itemBuilder: (context, i) {
                                  if (_selectedFolder != null && i == 0) {
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.folder_open,
                                        color: AppTheme.accent,
                                      ),
                                      title: const Text(
                                        '.. (Return)',
                                        style: TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          if (_selectedFolder!.contains('/')) {
                                            final parts = _selectedFolder!
                                                .split('/');
                                            parts.removeLast();
                                            _selectedFolder = parts.isEmpty
                                                ? null
                                                : parts.join('/');
                                          } else {
                                            _selectedFolder = null;
                                          }
                                        });
                                      },
                                    );
                                  }
                                  final folder =
                                      folders[_selectedFolder != null
                                          ? i - 1
                                          : i];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.folder,
                                      color: AppTheme.accent,
                                    ),
                                    title: Text(
                                      folder,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        if (_selectedFolder == null) {
                                          _selectedFolder = folder;
                                        } else {
                                          _selectedFolder =
                                              '$_selectedFolder/$folder';
                                        }
                                      });
                                    },
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
            // Floating Search Button (Positioned at bottom-right above the menu)
            Positioned(
              right: 16,
              bottom: 240, // More space to avoid overlap with mini player area
              child: _buildFloatingSearchBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isSearching ? MediaQuery.of(context).size.width - 32 : 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isSearching
          ? Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.search, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _isSearching = false;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search library...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
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
              child: const Icon(Icons.search, color: AppTheme.accent),
            ),
    );
  }

  Widget _buildReturnTile({
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: const Icon(Icons.arrow_back, color: AppTheme.accent),
      title: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildGridCard({
    required String title,
    required String subtitle,
    required String imageUrl,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppTheme.surfaceElevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.bgBase,
              child: const Icon(
                Icons.music_note,
                color: AppTheme.accent,
                size: 48,
              ),
            ),
          ),
          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.4, 0.7, 1.0],
              ),
            ),
          ),
          // Text Content
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
                    color: Colors.white.withOpacity(0.7),
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
    final baseUrl = auth.baseUrl ?? '';
    final token = auth.token ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: InkWell(
        onTap: () {
          final handler = ref.read(playerHandlerProvider);
          handler.loadQueue(allTracks, startIndex: index);
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                '$baseUrl/api/tracks/${track.id}/cover?auth=$token',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 52,
                  height: 52,
                  color: AppTheme.bgBase,
                  child: const Icon(Icons.music_note, color: AppTheme.accent),
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
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        track.artist,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FLAC',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.favorite_border,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.more_vert,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
