import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/player/equalizer_runtime_policy.dart';

void main() {
  test('equalizer playback pipeline stays disabled by default on Android', () {
    expect(
      isEqualizerPlaybackPipelineEnabled(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
  });

  test(
    'equalizer playback pipeline stays disabled on non-Android platforms',
    () {
      expect(
        isEqualizerPlaybackPipelineEnabled(
          isWeb: false,
          platform: TargetPlatform.iOS,
          experimentalFlag: true,
        ),
        isFalse,
      );
    },
  );

  test('equalizer playback pipeline only enables with explicit opt-in', () {
    expect(
      isEqualizerPlaybackPipelineEnabled(
        isWeb: false,
        platform: TargetPlatform.android,
        experimentalFlag: true,
      ),
      isTrue,
    );
  });
}
