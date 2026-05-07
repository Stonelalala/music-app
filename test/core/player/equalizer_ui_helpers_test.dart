import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/player/equalizer_presets.dart';

void main() {
  group('equalizer UI helpers', () {
    test('display profiles hide off and custom presets', () {
      final ids = EqualizerPresetProfile.displayProfiles
          .map((profile) => profile.id)
          .toList(growable: false);

      expect(ids, isNot(contains(EqualizerPresetId.off.id)));
      expect(ids, isNot(contains(EqualizerPresetId.custom.id)));
      expect(ids.first, EqualizerPresetId.natural.id);
      expect(ids, contains(EqualizerPresetId.rock.id));
    });

    test('formats equalizer frequencies for mobile labels', () {
      expect(formatEqualizerFrequencyLabel(31), '31');
      expect(formatEqualizerFrequencyLabel(62), '62');
      expect(formatEqualizerFrequencyLabel(125), '125');
      expect(formatEqualizerFrequencyLabel(1000), '1k');
      expect(formatEqualizerFrequencyLabel(16000), '16k');
      expect(formatEqualizerFrequencyLabel(16500), '16k');
    });
  });
}
