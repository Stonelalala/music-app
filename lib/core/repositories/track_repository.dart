import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../http/api_client.dart';
import '../../shared/models/track.dart';

class TrackRepository {
  final ApiClient _api;

  TrackRepository(this._api);

  Future<TracksResponse> getTracks({String? folder, int? status}) async {
    final params = <String, dynamic>{};
    if (folder != null) {
      params['folder'] = folder;
    }
    if (status != null) {
      params['status'] = status;
    }

    final data = await _api.get<Map<String, dynamic>>(
      '/api/tracks',
      params: params,
    );
    return TracksResponse.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<List<Track>> getRandomTracks() async {
    final data = await _api.get<Map<String, dynamic>>('/api/discovery/random');
    final list = data['data'] as List<dynamic>;
    return list.map((e) => Track.fromJson(e)).toList();
  }

  Future<List<Track>> getRecentTracks({int limit = 50}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/discovery/recent',
      params: {'limit': limit},
    );
    final list = data['data'] as List<dynamic>;
    return list.map((e) => Track.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getDiscoveryAlbums() async {
    final data = await _api.get<Map<String, dynamic>>('/api/discovery/albums');
    return (data['data'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<String?> getLyrics(String trackId) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/api/tracks/$trackId/lyrics',
      );
      return data['data'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<List<dynamic>> getRecommendSongs() async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/netease/recommend/songs',
    );
    return data['data'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getRecommendPlaylists() async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/netease/recommend/playlists',
    );
    return data['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>?> getPlaylistDetail(String id) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/api/netease/playlist/$id',
      );
      return data['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadNeteaseSong(String id, String level) async {
    await _api.post('/api/netease/download', data: {'id': id, 'level': level});
  }

  Future<void> downloadNeteasePlaylist(
    String id,
    String name,
    List<String> trackIds,
    String level,
  ) async {
    await _api.post(
      '/api/netease/download',
      data: {
        'id': id,
        'isPlaylist': true,
        'name': name,
        'trackIds': trackIds,
        'level': level,
      },
    );
  }
}

final trackRepositoryProvider = Provider<TrackRepository>(
  (ref) => TrackRepository(ref.watch(apiClientProvider)),
);
