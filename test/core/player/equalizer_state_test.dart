import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/player/equalizer_presets.dart';
import 'package:music/core/player/equalizer_state.dart';

void main() {
  test('snapshot builds gains for actual device band frequencies', () {
    final snapshot = EqualizerStateSnapshot.fromPreset(
      presetId: EqualizerPresetId.rock.id,
      enabled: true,
      bands: const [
        EqualizerBandSetting(index: 0, centerFrequency: 31, gain: 0),
        EqualizerBandSetting(index: 1, centerFrequency: 62, gain: 0),
        EqualizerBandSetting(index: 2, centerFrequency: 125, gain: 0),
        EqualizerBandSetting(index: 3, centerFrequency: 250, gain: 0),
        EqualizerBandSetting(index: 4, centerFrequency: 500, gain: 0),
      ],
    );

    expect(snapshot.enabled, isTrue);
    expect(snapshot.presetId, EqualizerPresetId.rock.id);
    expect(snapshot.bands.first.gain, greaterThan(0));
    expect(snapshot.bands[3].gain, greaterThan(snapshot.bands[4].gain));
  });

  test('updating a single band marks state as custom', () {
    final snapshot = EqualizerStateSnapshot.fromPreset(
      presetId: EqualizerPresetId.pop.id,
      enabled: true,
      bands: const [
        EqualizerBandSetting(index: 0, centerFrequency: 31, gain: 0),
        EqualizerBandSetting(index: 1, centerFrequency: 62, gain: 0),
      ],
    );

    final updated = snapshot.withBandGain(1, 4.5);

    expect(updated.presetId, EqualizerPresetId.custom.id);
    expect(updated.bands[1].gain, 4.5);
    expect(updated.bands[0].gain, snapshot.bands[0].gain);
  });

  test('snapshot serializes and restores enabled state and bands', () {
    const original = EqualizerStateSnapshot(
      enabled: true,
      presetId: 'custom',
      bands: [
        EqualizerBandSetting(index: 0, centerFrequency: 31, gain: 2.5),
        EqualizerBandSetting(index: 1, centerFrequency: 62, gain: -1.0),
      ],
    );

    final restored = EqualizerStateSnapshot.fromJson(original.toJson());

    expect(restored.enabled, isTrue);
    expect(restored.presetId, 'custom');
    expect(restored.bands.length, 2);
    expect(restored.bands[0].gain, 2.5);
    expect(restored.bands[1].gain, -1.0);
  });
}
