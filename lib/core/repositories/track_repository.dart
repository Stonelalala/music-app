import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../http/api_client.dart';
import '../../shared/models/track.dart';

class TrackRepository {
  final ApiClient _api;

  TrackRepository(this._api);

  Future<TracksResponse> getTracks({String? folder, int? status}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/tracks',
      params: {
        if (folder != null) 'folder': folder,
        if (status != null) 'status': status,
      },
    );
    return TracksResponse.fromJson(data['data'] as Map<String, dynamic>);
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
}

final trackRepositoryProvider = Provider<TrackRepository>(
  (ref) => TrackRepository(ref.watch(apiClientProvider)),
);
