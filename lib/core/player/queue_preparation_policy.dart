List<bool> buildQueueCachedSourcePlan({
  required int queueLength,
  required int currentIndex,
}) {
  if (queueLength <= 0) {
    return const <bool>[];
  }

  final safeIndex = currentIndex.clamp(0, queueLength - 1);
  return List<bool>.generate(
    queueLength,
    (index) => index == safeIndex,
    growable: false,
  );
}
