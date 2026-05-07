import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/player/playback_autoplay_policy.dart';

void main() {
  test('manual skip always resumes playback from a paused state', () {
    expect(
      resolveAutoPlayBehavior(
        trigger: PlaybackResumeTrigger.manualSkip,
        wasPlaying: false,
        autoPlayOnLaunchRestore: false,
      ),
      isTrue,
    );
  });

  test('launch restore can force autoplay for a paused session', () {
    expect(
      resolveAutoPlayBehavior(
        trigger: PlaybackResumeTrigger.launchRestore,
        wasPlaying: false,
        autoPlayOnLaunchRestore: true,
      ),
      isTrue,
    );
  });

  test('state-preserving restores keep paused sessions paused', () {
    expect(
      resolveAutoPlayBehavior(
        trigger: PlaybackResumeTrigger.statePreservingRestore,
        wasPlaying: false,
        autoPlayOnLaunchRestore: true,
      ),
      isFalse,
    );
  });
}
