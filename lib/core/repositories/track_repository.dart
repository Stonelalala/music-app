import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../http/api_client.dart';
import '../../shared/models/track.dart';
import '../../shared/models/discovery_album.dart';
import '../../shared/models/network_track.dart';

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

  Future<List<Track>> getRandomTracks({int limit = 30}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/discovery/random',
      params: {'limit': limit},
    );
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

  Future<List<DiscoveryAlbum>> getDiscoveryAlbums() async {
    final data = await _api.get<Map<String, dynamic>>('/api/discovery/albums');
    final list = data['data'] as List<dynamic>;
    return list
        .map((item) => DiscoveryAlbum.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Track>> getAlbumTracks({
    required String album,
    String? artist,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/discovery/album-tracks',
      params: {
        'album': album,
        if (artist != null && artist.trim().isNotEmpty) 'artist': artist,
      },
    );
    final list = data['data'] as List<dynamic>;
    return list
        .map((item) => Track.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<String?> getLyrics(String trackId) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/api/tracks/$trackId/lyrics',
      );
      return (data['lyrics'] ?? data['data']) as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> searchAndApplyLyrics(
    Track track, {
    String source = 'auto',
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/lyrics/search-web',
      params: {'title': track.title, 'artist': track.artist, 'source': source},
    );
    final lyrics = response['lyrics'] as String?;
    if (lyrics == null || lyrics.trim().isEmpty) {
      return null;
    }
    await _api.post(
      '/api/tracks/${track.id}',
      data: {
        'title': track.title,
        'artist': track.artist,
        'album': track.album,
        'year': track.year,
        'lyrics': lyrics,
      },
    );
    return lyrics;
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

  Future<void> downloadQQMusicSong(String id, String level) async {
    await _api.post('/api/qq/download', data: {'id': id, 'level': level});
  }

  Future<void> downloadKugouSong(String id, String level) async {
    await _api.post('/api/kugou/download', data: {'id': id, 'level': level});
  }

  Future<void> downloadKuwoSong(String id, String level) async {
    await _api.post('/api/kuwo/download', data: {'id': id, 'level': level});
  }

  Future<List<NetworkTrack>> searchNetworkTracks(
    String query,
    String source, {
    CancelToken? cancelToken,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/search-metadata',
      params: {'q': query, 'source': source},
      cancelToken: cancelToken,
    );
    final list = data['results'] as List<dynamic>? ?? [];
    return list
        .map(
          (item) => NetworkTrack.fromJson(
            item as Map<String, dynamic>,
            defaultSource: source,
          ),
        )
        .toList(growable: false);
  }

  Future<void> deleteTracks(List<String> ids) async {
    await _api.post('/api/tracks/delete', data: {'ids': ids});
  }

  Future<void> recordPlay(String trackId) async {
    await _api.post('/api/tracks/$trackId/play');
  }

  Future<List<Track>> getPlayHistory({int limit = 50}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/history',
      params: {'limit': limit},
    );
    final list = data['data'] as List<dynamic>;
    return list.map((e) => Track.fromJson(e)).toList();
  }
}

final trackRepositoryProvider = Provider<TrackRepository>(
  (ref) => TrackRepository(ref.watch(apiClientProvider)),
);
