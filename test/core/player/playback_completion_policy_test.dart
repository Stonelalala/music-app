import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/player/playback_completion_policy.dart';

void main() {
  test('single-track loop restarts current track', () {
    expect(
      resolvePlaybackCompletionAction(nextIndex: 3, isSingleTrackLoop: true),
      const PlaybackCompletionAction.restartCurrent(),
    );
  });

  test('queue completion advances to the next track when available', () {
    expect(
      resolvePlaybackCompletionAction(nextIndex: 4, isSingleTrackLoop: false),
      const PlaybackCompletionAction.playNext(4),
    );
  });

  test(
    'queue completion pauses on the current track when no next track exists',
    () {
      expect(
        resolvePlaybackCompletionAction(
          nextIndex: null,
          isSingleTrackLoop: false,
        ),
        const PlaybackCompletionAction.pauseCurrent(),
      );
    },
  );
}
