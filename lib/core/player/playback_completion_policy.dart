enum PlaybackCompletionKind { restartCurrent, playNext, pauseCurrent }

class PlaybackCompletionAction {
  const PlaybackCompletionAction._(this.kind, [this.nextIndex]);

  const PlaybackCompletionAction.restartCurrent()
    : this._(PlaybackCompletionKind.restartCurrent);

  const PlaybackCompletionAction.playNext(int nextIndex)
    : this._(PlaybackCompletionKind.playNext, nextIndex);

  const PlaybackCompletionAction.pauseCurrent()
    : this._(PlaybackCompletionKind.pauseCurrent);

  final PlaybackCompletionKind kind;
  final int? nextIndex;

  @override
  bool operator ==(Object other) {
    return other is PlaybackCompletionAction &&
        other.kind == kind &&
        other.nextIndex == nextIndex;
  }

  @override
  int get hashCode => Object.hash(kind, nextIndex);
}

PlaybackCompletionAction resolvePlaybackCompletionAction({
  required int? nextIndex,
  required bool isSingleTrackLoop,
}) {
  if (isSingleTrackLoop) {
    return const PlaybackCompletionAction.restartCurrent();
  }
  if (nextIndex != null) {
    return PlaybackCompletionAction.playNext(nextIndex);
  }
  return const PlaybackCompletionAction.pauseCurrent();
}
