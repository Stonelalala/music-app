import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final int maxCacheSizeMB; // 单位 MB

  SettingsState({required this.maxCacheSizeMB});

  SettingsState copyWith({int? maxCacheSizeMB}) {
    return SettingsState(
      maxCacheSizeMB: maxCacheSizeMB ?? this.maxCacheSizeMB,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  static const String _maxCacheKey = 'max_cache_size_mb';
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs)
      : super(SettingsState(
          maxCacheSizeMB: _prefs.getInt(_maxCacheKey) ?? 512, // 默认 512MB
        ));

  Future<void> setMaxCacheSize(int sizeMB) async {
    await _prefs.setInt(_maxCacheKey, sizeMB);
    state = state.copyWith(maxCacheSizeMB: sizeMB);
  }

  // 转换字节
  int get maxCacheSizeBytes => state.maxCacheSizeMB * 1024 * 1024;
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize synchronously in main.dart');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
