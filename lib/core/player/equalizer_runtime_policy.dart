import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const bool kEnableExperimentalEqualizerPlaybackPipeline = false;

bool isEqualizerPlaybackPipelineEnabled({
  required bool isWeb,
  required TargetPlatform platform,
  bool experimentalFlag = kEnableExperimentalEqualizerPlaybackPipeline,
}) {
  return experimentalFlag && !isWeb && platform == TargetPlatform.android;
}
