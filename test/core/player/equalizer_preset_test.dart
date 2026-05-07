import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/player/equalizer_presets.dart';

void main() {
  group('EqualizerPresetProfile', () {
    test('supports stable preset lookup by id', () {
      expect(
        EqualizerPresetProfile.fromId(EqualizerPresetId.rock.id).id,
        EqualizerPresetId.rock.id,
      );
      expect(
        EqualizerPresetProfile.fromId('unknown').id,
        EqualizerPresetId.off.id,
      );
    });

    test('off preset keeps all frequencies neutral', () {
      final off = EqualizerPresetProfile.fromId(EqualizerPresetId.off.id);

      expect(off.gainForFrequency(60), 0);
      expect(off.gainForFrequency(1000), 0);
      expect(off.gainForFrequency(12000), 0);
    });

    test('rock preset boosts bass and treble more than mids', () {
      final rock = EqualizerPresetProfile.fromId(EqualizerPresetId.rock.id);

      expect(
        rock.gainForFrequency(60),
        greaterThan(rock.gainForFrequency(1000)),
      );
      expect(
        rock.gainForFrequency(12000),
        greaterThan(rock.gainForFrequency(1000)),
      );
    });

    test('vocal preset emphasizes mids over bass', () {
      final vocal = EqualizerPresetProfile.fromId(EqualizerPresetId.vocal.id);

      expect(
        vocal.gainForFrequency(1000),
        greaterThan(vocal.gainForFrequency(60)),
      );
    });
  });
}
