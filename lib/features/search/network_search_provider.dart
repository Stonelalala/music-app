import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/track_repository.dart';
import '../../shared/models/network_track.dart';

// Current network search source, e.g. "netease" or "qq".
final networkSearchSourceProvider = StateProvider<String>((ref) => 'netease');

// Current network search query text.
final networkSearchQueryProvider = StateProvider<String>((ref) => '');

// Network search results.
final networkSearchResultsProvider =
    FutureProvider.autoDispose<List<NetworkTrack>>((ref) async {
      final query = ref.watch(networkSearchQueryProvider);
      final source = ref.watch(networkSearchSourceProvider);

      if (query.trim().isEmpty) {
        return [];
      }

      final cancelToken = CancelToken();
      ref.onDispose(() {
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('search query changed');
        }
      });

      final repository = ref.watch(trackRepositoryProvider);
      return repository.searchNetworkTracks(
        query,
        source,
        cancelToken: cancelToken,
      );
    });
