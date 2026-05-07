enum PlaybackResumeTrigger { launchRestore, manualSkip, statePreservingRestore }

bool resolveAutoPlayBehavior({
  required PlaybackResumeTrigger trigger,
  required bool wasPlaying,
  required bool autoPlayOnLaunchRestore,
}) {
  return switch (trigger) {
    PlaybackResumeTrigger.launchRestore =>
      autoPlayOnLaunchRestore || wasPlaying,
    PlaybackResumeTrigger.manualSkip => true,
    PlaybackResumeTrigger.statePreservingRestore => wasPlaying,
  };
}
