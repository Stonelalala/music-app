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

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksDataProvider(_selectedFolder));

    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      appBar: AppBar(
        leading: const Icon(
          Icons.settings_outlined,
          size: 24,
          color: AppTheme.accent,
        ),
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 24, color: AppTheme.accent),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Navigation Tabs
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['Artists', 'Albums', 'Songs', 'Folders'].map((tab) {
                  final isSelected = _activeTab == tab;
                  return GestureDetector(
                    onTap: () => setState(() => _activeTab = tab),
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

          // Quality Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['FLAC', '24-BIT', 'ALAC', 'DSD'].map((label) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
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
                      final tracks = data.tracks;
                      return ListView.builder(
                        itemCount: tracks.length,
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          100,
                        ), // 增加底部 Padding，防止遮挡
                        itemBuilder: (context, i) => _TrackTile(
                          track: tracks[i],
                          allTracks: tracks,
                          index: i,
                        ),
                      );
                    },
                  ),
                ),
                // Alphabet Scroller
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 16, bottom: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#'.split('').map((c) {
                      return Text(
                        c,
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
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
