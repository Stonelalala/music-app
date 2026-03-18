import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/collection_repository.dart';
import '../../core/repositories/track_repository.dart';
import '../../shared/models/play_stats.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';

final favoritesProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  return ref.watch(collectionRepositoryProvider).getFavorites();
});

final favoriteStatusProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, trackId) async {
      return ref.watch(collectionRepositoryProvider).isFavorite(trackId);
    });

final playlistsProvider = FutureProvider.autoDispose<List<UserPlaylist>>((
  ref,
) async {
  return ref.watch(collectionRepositoryProvider).getPlaylists();
});

final playlistDetailProvider =
    FutureProvider.autoDispose.family<PlaylistDetail, String>((ref, playlistId) async {
      return ref.watch(collectionRepositoryProvider).getPlaylistDetail(playlistId);
    });

final smartPlaylistsProvider =
    FutureProvider.autoDispose<List<SmartPlaylistSummary>>((ref) async {
      return ref.watch(collectionRepositoryProvider).getSmartPlaylists();
    });

final smartPlaylistDetailProvider =
    FutureProvider.autoDispose.family<PlaylistDetail, String>((ref, playlistId) async {
      return ref.watch(collectionRepositoryProvider).getSmartPlaylistDetail(playlistId);
    });

final playStatsProvider = FutureProvider.autoDispose<PlayStats>((ref) async {
  return ref.watch(collectionRepositoryProvider).getPlayStats();
});

final recentHistoryProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  return ref.watch(trackRepositoryProvider).getPlayHistory(limit: 30);
});
