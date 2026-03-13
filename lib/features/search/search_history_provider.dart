import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings/settings_provider.dart';

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  final SharedPreferences _prefs;
  static const _key = 'search_history';

  SearchHistoryNotifier(this._prefs) : super([]) {
    _loadHistory();
  }

  void _loadHistory() {
    final history = _prefs.getStringList(_key);
    if (history != null) {
      state = history;
    }
  }

  Future<void> addQuery(String query) async {
    if (query.trim().isEmpty) return;
    
    final newState = [
      query,
      ...state.where((q) => q != query),
    ].take(10).toList(); // Keep last 10
    
    state = newState;
    await _prefs.setStringList(_key, newState);
  }

  Future<void> removeQuery(String query) async {
    final newState = state.where((q) => q != query).toList();
    state = newState;
    await _prefs.setStringList(_key, newState);
  }

  Future<void> clearHistory() async {
    state = [];
    await _prefs.remove(_key);
  }
}

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SearchHistoryNotifier(prefs);
});
