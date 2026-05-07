import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/player/queue_preparation_policy.dart';

void main() {
  test('queue cache lookup plan only resolves the current track eagerly', () {
    expect(buildQueueCachedSourcePlan(queueLength: 5, currentIndex: 2), <bool>[
      false,
      false,
      true,
      false,
      false,
    ]);
  });

  test('queue cache lookup plan returns empty for an empty queue', () {
    expect(
      buildQueueCachedSourcePlan(queueLength: 0, currentIndex: 0),
      isEmpty,
    );
  });
}
