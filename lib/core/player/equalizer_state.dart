import 'equalizer_presets.dart';

class EqualizerBandSetting {
  const EqualizerBandSetting({
    required this.index,
    required this.centerFrequency,
    required this.gain,
  });

  final int index;
  final double centerFrequency;
  final double gain;

  EqualizerBandSetting copyWith({
    int? index,
    double? centerFrequency,
    double? gain,
  }) {
    return EqualizerBandSetting(
      index: index ?? this.index,
      centerFrequency: centerFrequency ?? this.centerFrequency,
      gain: gain ?? this.gain,
    );
  }

  Map<String, dynamic> toJson() => {
    'index': index,
    'centerFrequency': centerFrequency,
    'gain': gain,
  };

  factory EqualizerBandSetting.fromJson(Map<String, dynamic> json) {
    return EqualizerBandSetting(
      index: (json['index'] as num?)?.toInt() ?? 0,
      centerFrequency: (json['centerFrequency'] as num?)?.toDouble() ?? 0,
      gain: (json['gain'] as num?)?.toDouble() ?? 0,
    );
  }
}

class EqualizerStateSnapshot {
  const EqualizerStateSnapshot({
    required this.enabled,
    required this.presetId,
    required this.bands,
  });

  final bool enabled;
  final String presetId;
  final List<EqualizerBandSetting> bands;

  factory EqualizerStateSnapshot.empty() {
    return const EqualizerStateSnapshot(
      enabled: false,
      presetId: 'off',
      bands: <EqualizerBandSetting>[],
    );
  }

  factory EqualizerStateSnapshot.fromPreset({
    required String presetId,
    required bool enabled,
    required List<EqualizerBandSetting> bands,
  }) {
    final profile = EqualizerPresetProfile.fromId(presetId);
    return EqualizerStateSnapshot(
      enabled: enabled,
      presetId: profile.id,
      bands: bands
          .map(
            (band) => band.copyWith(
              gain: profile.gainForFrequency(band.centerFrequency),
            ),
          )
          .toList(growable: false),
    );
  }

  EqualizerStateSnapshot withBands(List<EqualizerBandSetting> nextBands) {
    return EqualizerStateSnapshot(
      enabled: enabled,
      presetId: presetId,
      bands: nextBands,
    );
  }

  EqualizerStateSnapshot withBandGain(int bandIndex, double gain) {
    final updatedBands = bands
        .map(
          (band) => band.index == bandIndex ? band.copyWith(gain: gain) : band,
        )
        .toList(growable: false);
    return EqualizerStateSnapshot(
      enabled: true,
      presetId: EqualizerPresetId.custom.id,
      bands: updatedBands,
    );
  }

  EqualizerStateSnapshot copyWith({
    bool? enabled,
    String? presetId,
    List<EqualizerBandSetting>? bands,
  }) {
    return EqualizerStateSnapshot(
      enabled: enabled ?? this.enabled,
      presetId: presetId ?? this.presetId,
      bands: bands ?? this.bands,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'presetId': presetId,
    'bands': bands.map((band) => band.toJson()).toList(growable: false),
  };

  factory EqualizerStateSnapshot.fromJson(Map<String, dynamic> json) {
    final rawBands = json['bands'] as List<dynamic>? ?? const [];
    return EqualizerStateSnapshot(
      enabled: json['enabled'] as bool? ?? false,
      presetId: json['presetId'] as String? ?? EqualizerPresetId.off.id,
      bands: rawBands
          .map((item) => EqualizerBandSetting.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
