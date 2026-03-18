import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../http/api_client.dart';

class SyncRepository {
  SyncRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> getPreferences() async {
    final data = await _api.get<Map<String, dynamic>>('/api/preferences');
    return (data['data'] as Map<String, dynamic>?) ?? const {};
  }

  Future<void> setPreference(String key, Object? value) async {
    await _api.put(
      '/api/preferences/$key',
      data: {'value': value},
    );
  }
}

final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => SyncRepository(ref.watch(apiClientProvider)),
);
