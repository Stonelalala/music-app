import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/features/search/search_query_debouncer.dart';

void main() {
  test('debouncer only commits the latest scheduled query after the delay', () {
    fakeAsync((async) {
      final debouncer = SearchQueryDebouncer(
        delay: const Duration(milliseconds: 300),
      );
      final committed = <String>[];

      debouncer.schedule(' first ', committed.add);
      async.elapse(const Duration(milliseconds: 200));
      debouncer.schedule(' second ', committed.add);

      async.elapse(const Duration(milliseconds: 299));
      expect(committed, isEmpty);

      async.elapse(const Duration(milliseconds: 1));
      expect(committed, ['second']);
    });
  });

  test('flush commits immediately and cancels the pending timer', () {
    fakeAsync((async) {
      final debouncer = SearchQueryDebouncer(
        delay: const Duration(milliseconds: 300),
      );
      final committed = <String>[];

      debouncer.schedule(' later ', committed.add);
      debouncer.flush(' now ', committed.add);

      expect(committed, ['now']);
      async.elapse(const Duration(milliseconds: 300));
      expect(committed, ['now']);
    });
  });
}
