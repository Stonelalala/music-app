import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/player/equalizer_presets.dart';
import '../../core/player/equalizer_state.dart';
import '../../core/player/player_service.dart';

class EqualizerPage extends ConsumerStatefulWidget {
  const EqualizerPage({super.key});

  @override
  ConsumerState<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends ConsumerState<EqualizerPage> {
  late final MusicPlayerHandler _handler;

  bool _initializing = true;
  bool _enabled = false;
  String _selectedPresetId = EqualizerPresetId.off.id;
  List<EqualizerBandSetting> _bands = const <EqualizerBandSetting>[];
  double _minDecibels = -12;
  double _maxDecibels = 12;

  @override
  void initState() {
    super.initState();
    _handler = ref.read(playerHandlerProvider);
    _handler.addListener(_syncFromHandler);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _handler.removeListener(_syncFromHandler);
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_handler.supportsEqualizer) {
      await _handler.prepareEqualizer();
    }
    if (!mounted) {
      return;
    }
    _syncFromHandler();
    setState(() {
      _initializing = false;
    });
  }

  void _syncFromHandler() {
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = _handler.equalizerEnabled;
      _selectedPresetId = _handler.equalizerPresetId;
      _bands = List<EqualizerBandSetting>.from(_handler.equalizerBands);
      _minDecibels = _handler.equalizerMinDecibels;
      _maxDecibels = _handler.equalizerMaxDecibels;
    });
  }

  List<EqualizerBandSetting> _previewBands() {
    if (_bands.isNotEmpty) {
      return _bands;
    }
    const fallbackFrequencies = <double>[
      31,
      62,
      125,
      250,
      500,
      1000,
      2000,
      4000,
      8000,
      16000,
    ];
    return List<EqualizerBandSetting>.generate(
      fallbackFrequencies.length,
      (index) => EqualizerBandSetting(
        index: index,
        centerFrequency: fallbackFrequencies[index],
        gain: 0,
      ),
      growable: false,
    );
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      final presetToApply = _selectedPresetId == EqualizerPresetId.off.id
          ? EqualizerPresetId.natural.id
          : _selectedPresetId;
      if (_selectedPresetId == EqualizerPresetId.off.id) {
        final preview = EqualizerStateSnapshot.fromPreset(
          presetId: presetToApply,
          enabled: true,
          bands: _previewBands(),
        );
        setState(() {
          _enabled = true;
          _selectedPresetId = presetToApply;
          _bands = preview.bands;
        });
        await _handler.setEqualizerPreset(presetToApply);
        return;
      }

      setState(() {
        _enabled = true;
      });
      await _handler.setEqualizerEnabled(true);
      return;
    }

    setState(() {
      _enabled = false;
    });
    await _handler.setEqualizerEnabled(false);
  }

  void _applyPreset(EqualizerPresetProfile profile) {
    final preview = EqualizerStateSnapshot.fromPreset(
      presetId: profile.id,
      enabled: true,
      bands: _previewBands(),
    );

    setState(() {
      _enabled = true;
      _selectedPresetId = profile.id;
      _bands = preview.bands;
    });

    unawaited(_handler.setEqualizerPreset(profile.id));
  }

  void _updateBand(int bandIndex, double gain) {
    setState(() {
      _enabled = true;
      _selectedPresetId = EqualizerPresetId.custom.id;
      _bands = _bands
          .map(
            (band) =>
                band.index == bandIndex ? band.copyWith(gain: gain) : band,
          )
          .toList(growable: false);
    });

    if (!_handler.equalizerEnabled) {
      unawaited(_handler.setEqualizerEnabled(true, syncRemote: false));
    }
    unawaited(_handler.setEqualizerBandGain(bandIndex, gain, persist: false));
  }

  Future<void> _commitBand(int bandIndex, double gain) async {
    await _handler.setEqualizerBandGain(bandIndex, gain, persist: true);
  }

  String _formatGain(double value) {
    final rounded = value.round();
    if (rounded > 0) {
      return '+$rounded';
    }
    return '$rounded';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('均衡器'),
      ),
      body: !_handler.supportsEqualizer
          ? Center(
              child: Text(
                '当前设备暂不支持均衡器',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          : _initializing && _bands.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.72,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.22,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '是否启用',
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _selectedPresetId ==
                                              EqualizerPresetId.custom.id
                                          ? '当前为自定义曲线'
                                          : '当前预设 ${EqualizerPresetProfile.fromId(_selectedPresetId).label}',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _enabled,
                                onChanged: _toggleEnabled,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 260,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: _bands
                                  .map(
                                    (band) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: _EqualizerBandColumn(
                                          band: band,
                                          minDecibels: _minDecibels,
                                          maxDecibels: _maxDecibels,
                                          enabled: _enabled,
                                          gainLabel: _formatGain(band.gain),
                                          onChanged: (value) =>
                                              _updateBand(band.index, value),
                                          onChangeEnd: (value) =>
                                              _commitBand(band.index, value),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: EqualizerPresetProfile.displayProfiles.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.45,
                          ),
                      itemBuilder: (context, index) {
                        final profile =
                            EqualizerPresetProfile.displayProfiles[index];
                        return _EqualizerPresetCard(
                          profile: profile,
                          selected: _enabled && _selectedPresetId == profile.id,
                          onTap: () => _applyPreset(profile),
                          colorScheme: colorScheme,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EqualizerBandColumn extends StatelessWidget {
  const _EqualizerBandColumn({
    required this.band,
    required this.minDecibels,
    required this.maxDecibels,
    required this.enabled,
    required this.gainLabel,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final EqualizerBandSetting band;
  final double minDecibels;
  final double maxDecibels;
  final bool enabled;
  final String gainLabel;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: _VerticalEqualizerSlider(
            min: minDecibels,
            max: maxDecibels,
            value: band.gain.clamp(minDecibels, maxDecibels).toDouble(),
            activeColor: colorScheme.primary,
            inactiveColor: colorScheme.onSurface.withValues(alpha: 0.12),
            onChanged: enabled ? onChanged : null,
            onChangeEnd: enabled ? onChangeEnd : null,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          formatEqualizerFrequencyLabel(band.centerFrequency),
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          gainLabel,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _VerticalEqualizerSlider extends StatelessWidget {
  const _VerticalEqualizerSlider({
    required this.min,
    required this.max,
    required this.value,
    required this.activeColor,
    required this.inactiveColor,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double min;
  final double max;
  final double value;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Transform.rotate(
          angle: -math.pi / 2,
          child: SizedBox(
            width: constraints.maxHeight,
            height: constraints.maxWidth,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: activeColor,
                inactiveTrackColor: inactiveColor,
                thumbColor: Colors.white,
              ),
              child: Slider(
                min: min,
                max: max,
                value: value.clamp(min, max),
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EqualizerPresetCard extends StatelessWidget {
  const _EqualizerPresetCard({
    required this.profile,
    required this.selected,
    required this.onTap,
    required this.colorScheme,
  });

  final EqualizerPresetProfile profile;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.62)
                : colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.44)
                  : colorScheme.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CustomPaint(
                  painter: _PresetCurvePainter(
                    profile: profile,
                    lineColor: selected
                        ? colorScheme.primary
                        : colorScheme.secondary,
                    pointColor: Colors.white.withValues(alpha: 0.65),
                    gridColor: colorScheme.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                profile.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetCurvePainter extends CustomPainter {
  const _PresetCurvePainter({
    required this.profile,
    required this.lineColor,
    required this.pointColor,
    required this.gridColor,
  });

  final EqualizerPresetProfile profile;
  final Color lineColor;
  final Color pointColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final pointPaint = Paint()..color = pointColor;

    const minGain = -4.5;
    const maxGain = 4.5;
    final keys = profile.controlPoints.keys.toList()..sort();
    if (keys.isEmpty) {
      return;
    }

    final bandCount = keys.length;
    for (var i = 0; i < 5; i++) {
      final y = rect.top + rect.height * (i / 4);
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }
    for (var i = 0; i < bandCount; i++) {
      final x = rect.left + rect.width * (i / (bandCount - 1));
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < bandCount; i++) {
      final x = rect.left + rect.width * (i / (bandCount - 1));
      final gain = profile.controlPoints[keys[i]] ?? 0;
      final normalized = ((gain - minGain) / (maxGain - minGain)).clamp(
        0.0,
        1.0,
      );
      final y = rect.bottom - rect.height * normalized;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < bandCount; i++) {
      final x = rect.left + rect.width * (i / (bandCount - 1));
      final gain = profile.controlPoints[keys[i]] ?? 0;
      final normalized = ((gain - minGain) / (maxGain - minGain)).clamp(
        0.0,
        1.0,
      );
      final y = rect.bottom - rect.height * normalized;
      canvas.drawCircle(Offset(x, y), 2.6, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PresetCurvePainter oldDelegate) {
    return oldDelegate.profile.id != profile.id ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.gridColor != gridColor;
  }
}
