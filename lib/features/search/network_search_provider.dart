import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/repositories/track_repository.dart';
import '../../shared/models/network_track.dart';

// 当前搜索的源：'netease' 或 'qq'
final networkSearchSourceProvider = StateProvider<String>((ref) => 'netease');

// 搜索输入框的值
final networkSearchQueryProvider = StateProvider<String>((ref) => '');

// 搜索结果
final networkSearchResultsProvider = FutureProvider<List<NetworkTrack>>((ref) async {
  final query = ref.watch(networkSearchQueryProvider);
  final source = ref.watch(networkSearchSourceProvider);
  
  if (query.trim().isEmpty) {
    return [];
  }
  
  final repository = ref.watch(trackRepositoryProvider);
  return repository.searchNetworkTracks(query, source);
});
