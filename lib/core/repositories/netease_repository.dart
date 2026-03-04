import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../http/api_client.dart';
import '../../shared/models/netease.dart';

class NeteaseRepository {
  final ApiClient _api;

  NeteaseRepository(this._api);

  Future<List<NeteasePlaylist>> getRecommendPlaylists() async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/netease/recommend/playlists',
    );
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => NeteasePlaylist.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NeteaseSong>> getRecommendSongs() async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/netease/recommend/songs',
    );
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => NeteaseSong.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NeteasePlaylistDetail> getPlaylistDetail(String id) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/api/netease/playlist/$id',
    );
    return NeteasePlaylistDetail.fromJson(data['data'] as Map<String, dynamic>);
  }
}

final neteaseRepositoryProvider = Provider<NeteaseRepository>(
  (ref) => NeteaseRepository(ref.watch(apiClientProvider)),
);
