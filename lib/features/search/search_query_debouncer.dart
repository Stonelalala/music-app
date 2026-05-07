import 'dart:async';

typedef SearchQueryCommit = void Function(String query);

class SearchQueryDebouncer {
  SearchQueryDebouncer({this.delay = const Duration(milliseconds: 350)});

  final Duration delay;
  Timer? _timer;

  void schedule(String rawQuery, SearchQueryCommit onCommit) {
    final query = rawQuery.trim();
    _timer?.cancel();
    _timer = Timer(delay, () => onCommit(query));
  }

  void flush(String rawQuery, SearchQueryCommit onCommit) {
    cancel();
    onCommit(rawQuery.trim());
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}
