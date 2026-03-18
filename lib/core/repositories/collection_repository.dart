import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/play_stats.dart';
import '../../shared/models/playlist.dart';
import '../../shared/models/track.dart';
import '../http/api_client.dart';

class CollectionRepository {
  final ApiClient _api;

  CollectionRepository(this._api);

  bool _isNotFound(DioException error) => error.response?.statusCode == 404;

  Future<List<Track>> getFavorites() async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/api/favorites');
      final list = data['data'] as List<dynamic>? ?? const [];
      return list.map((item) => Track.fromJson(item as Map<String, dynamic>)).toList();
    } on DioException catch (error) {
      if (_isNotFound(error)) {
        return const [];
      }
      rethrow;
    }
  }

  Future<bool> isFavorite(String trackId) async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/api/favorites/$trackId/status');
      final payload = data['data'] as Map<String, dynamic>? ?? const {};
      return payload['isFavorite'] as bool? ?? false;
    } on DioException catch (error) {
      if (_isNotFound(error)) {
        return false;
      }
      rethrow;
    }
  }

  Future<void> addFavorite(String trackId) async {
    await _api.post('/api/favorites/$trackId');
  }

  Future<void> removeFavorite(String trackId) async {
    await _api.delete('/api/favorites/$trackId');
  }

  Future<List<UserPlaylist>> getPlaylists() async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/api/playlists');
      final list = data['data'] as List<dynamic>? ?? const [];
      return list
          .map((item) => UserPlaylist.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (error) {
      if (_isNotFound(error)) {
        return const [];
      }
      rethrow;
    }
  }

  Future<PlaylistDetail> getPlaylistDetail(String playlistId) async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/api/playlists/$playlistId');
      return PlaylistDetail.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      if (_isNotFound(error)) {
        return PlaylistDetail(
          id: playlistId,
          name: '歌单不可用',
          trackCount: 0,
          tracks: const [],
        );
      }
      rethrow;
    }
  }

  Future<UserPlaylist> createPlaylist(String name) async {
    return createPlaylistWithTracks(name, const []);
  }

  Future<UserPlaylist> createPlaylistWithTracks(
    String name,
    List<String> trackIds, {
    String? coverTrackId,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'trackIds': trackIds,
    };
    if (coverTrackId != null) {
      payload['coverTrackId'] = coverTrackId;
    }
    final data = await _api.post<Map<String, dynamic>>(
      '/api/playlists',
      data: payload,
    );
    return UserPlaylist.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> updatePlaylist(
    String playlistId, {
    String? name,
    String? coverTrackId,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) {
      payload['name'] = name;
    }
    if (coverTrackId != null) {
      payload['coverTrackId'] = coverTrackId;
    }
    await _api.dio.patch('/api/playlists/$playlistId', data: payload);
  }

  Future<void> renamePlaylist(String playlistId, String name) async {
    await updatePlaylist(playlistId, name: name);
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _api.delete('/api/playlists/$playlistId');
  }

  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    await _api.post('/api/playlists/$playlistId/tracks', data: {'trackId': trackId});
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _api.delete('/api/playlists/$playlistId/tracks/$trackId');
  }

  Future<void> reorderPlaylistTracks(
    String playlistId,
    List<String> trackIds, {
    String? coverTrackId,
  }) async {
    final payload = <String, dynamic>{
      'trackIds': trackIds,
    };
    if (coverTrackId != null) {
      payload['coverTrackId'] = coverTrackId;
    }
    await _api.dio.put(
      '/api/playlists/$playlistId/tracks/reorder',
      data: payload,
    );
  }

  Future<List<SmartPlaylistSummary>> getSmartPlaylists() async {
    final data = await _api.get<Map<String, dynamic>>('/api/playlists/smart');
    final list = data['data'] as List<dynamic>? ?? const [];
    return list
        .map((item) => SmartPlaylistSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PlaylistDetail> getSmartPlaylistDetail(String smartId) async {
    final key = smartId.replaceFirst('smart:', '');
    final data = await _api.get<Map<String, dynamic>>('/api/playlists/smart/$key');
    return PlaylistDetail.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> exportData() async {
    final data = await _api.get<Map<String, dynamic>>('/api/data/export');
    return data['data'] as Map<String, dynamic>? ?? const {};
  }

  Future<void> importData(
    Map<String, dynamic> payload, {
    bool replace = false,
  }) async {
    await _api.post(
      '/api/data/import',
      data: {
        'mode': replace ? 'replace' : 'merge',
        'data': payload,
      },
    );
  }

  Future<PlayStats> getPlayStats() async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/api/play-stats');
      return PlayStats.fromJson(data['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      if (_isNotFound(error)) {
        return const PlayStats(
          totalPlays: 0,
          uniqueTracks: 0,
          favoriteTracks: 0,
          playlists: 0,
          topTracks: [],
        );
      }
      rethrow;
    }
  }
}

final collectionRepositoryProvider = Provider<CollectionRepository>(
  (ref) => CollectionRepository(ref.watch(apiClientProvider)),
);
