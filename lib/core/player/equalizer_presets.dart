enum EqualizerPresetId {
  off('off'),
  custom('custom'),
  natural('natural'),
  pop('pop'),
  dance('dance'),
  blues('blues'),
  classical('classical'),
  rock('rock'),
  jazz('jazz'),
  ballad('ballad'),
  electronic('electronic'),
  country('country'),
  folk('folk'),
  vocal('vocal'),
  bassBoost('bass_boost');

  const EqualizerPresetId(this.id);
  final String id;
}

class EqualizerPresetProfile {
  EqualizerPresetProfile._({
    required this.id,
    required this.label,
    required this.controlPoints,
  });

  final String id;
  final String label;
  final Map<double, double> controlPoints;

  static final profiles = <EqualizerPresetProfile>[
    EqualizerPresetProfile._(
      id: EqualizerPresetId.off.id,
      label: '关闭',
      controlPoints: {
        60: 0,
        170: 0,
        310: 0,
        600: 0,
        1000: 0,
        3000: 0,
        6000: 0,
        12000: 0,
        14000: 0,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.custom.id,
      label: '自定义',
      controlPoints: {
        60: 0,
        170: 0,
        310: 0,
        600: 0,
        1000: 0,
        3000: 0,
        6000: 0,
        12000: 0,
        14000: 0,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.natural.id,
      label: '原声',
      controlPoints: {
        60: 0.2,
        170: 0.1,
        310: 0,
        600: 0,
        1000: 0,
        3000: 0.1,
        6000: 0.2,
        12000: 0.15,
        14000: 0.1,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.pop.id,
      label: '流行',
      controlPoints: {
        60: 2.0,
        170: 1.4,
        310: 0.4,
        600: -0.2,
        1000: 0.2,
        3000: 1.0,
        6000: 1.8,
        12000: 2.0,
        14000: 1.8,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.dance.id,
      label: '舞曲',
      controlPoints: {
        60: 2.8,
        170: 2.1,
        310: 1.2,
        600: 0.2,
        1000: -0.4,
        3000: -0.8,
        6000: -1.0,
        12000: 1.2,
        14000: 1.0,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.blues.id,
      label: '蓝调',
      controlPoints: {
        60: -0.2,
        170: 0.8,
        310: 1.6,
        600: 2.2,
        1000: 0.8,
        3000: -0.6,
        6000: 0.8,
        12000: 1.8,
        14000: 2.2,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.classical.id,
      label: '古典',
      controlPoints: {
        60: 0.4,
        170: 0.4,
        310: 0.4,
        600: 0.2,
        1000: 0.2,
        3000: -2.2,
        6000: -1.8,
        12000: -1.6,
        14000: -2.6,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.rock.id,
      label: '摇滚',
      controlPoints: {
        60: 3.2,
        170: 2.4,
        310: 1.2,
        600: 0.2,
        1000: -0.4,
        3000: 1.2,
        6000: 2.4,
        12000: 3.0,
        14000: 2.6,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.jazz.id,
      label: '爵士',
      controlPoints: {
        60: 1.2,
        170: 0.8,
        310: 0.2,
        600: 0.6,
        1000: 1.0,
        3000: 1.6,
        6000: 1.8,
        12000: 1.4,
        14000: 1.0,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.ballad.id,
      label: '慢歌',
      controlPoints: {
        60: -0.6,
        170: -1.0,
        310: -1.6,
        600: -2.2,
        1000: -3.0,
        3000: -1.4,
        6000: 0.4,
        12000: 1.4,
        14000: 2.0,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.electronic.id,
      label: '电子乐',
      controlPoints: {
        60: 1.4,
        170: 1.2,
        310: -0.2,
        600: -1.6,
        1000: -2.6,
        3000: -1.6,
        6000: 0.4,
        12000: 2.2,
        14000: 2.0,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.country.id,
      label: '乡村',
      controlPoints: {
        60: 0.8,
        170: 1.0,
        310: 0.2,
        600: -1.8,
        1000: -2.8,
        3000: -1.2,
        6000: -1.0,
        12000: 1.8,
        14000: 0.8,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.folk.id,
      label: '民谣',
      controlPoints: {
        60: -0.6,
        170: -0.2,
        310: 0.4,
        600: 1.0,
        1000: 1.5,
        3000: 1.8,
        6000: 1.0,
        12000: 0.4,
        14000: 0,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.vocal.id,
      label: '人声',
      controlPoints: {
        60: -1.2,
        170: -0.8,
        310: 0.4,
        600: 1.6,
        1000: 2.6,
        3000: 2.8,
        6000: 1.2,
        12000: 0.2,
        14000: -0.2,
      },
    ),
    EqualizerPresetProfile._(
      id: EqualizerPresetId.bassBoost.id,
      label: '低音增强',
      controlPoints: {
        60: 4.0,
        170: 3.0,
        310: 1.6,
        600: 0.4,
        1000: -0.4,
        3000: -0.6,
        6000: -0.4,
        12000: 0,
        14000: 0.2,
      },
    ),
  ];

  static final displayProfiles = profiles
      .where(
        (profile) =>
            profile.id != EqualizerPresetId.off.id &&
            profile.id != EqualizerPresetId.custom.id,
      )
      .toList(growable: false);

  static EqualizerPresetProfile fromId(String? id) {
    return profiles.firstWhere(
      (profile) => profile.id == id,
      orElse: () => profiles.first,
    );
  }

  double gainForFrequency(double frequency) {
    final keys = controlPoints.keys.toList()..sort();
    if (keys.isEmpty) {
      return 0;
    }
    if (frequency <= keys.first) {
      return controlPoints[keys.first]!;
    }
    if (frequency >= keys.last) {
      return controlPoints[keys.last]!;
    }

    for (var i = 0; i < keys.length - 1; i++) {
      final lower = keys[i];
      final upper = keys[i + 1];
      if (frequency >= lower && frequency <= upper) {
        final lowerGain = controlPoints[lower]!;
        final upperGain = controlPoints[upper]!;
        final ratio = (frequency - lower) / (upper - lower);
        return lowerGain + (upperGain - lowerGain) * ratio;
      }
    }
    return 0;
  }
}

String formatEqualizerFrequencyLabel(double frequency) {
  final rounded = frequency.round();
  if (rounded >= 1000) {
    return '${(rounded / 1000).floor()}k';
  }
  return '$rounded';
}
