import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class LaunchSplashOverlay extends StatefulWidget {
  const LaunchSplashOverlay({super.key, required this.visible});

  final bool visible;

  @override
  State<LaunchSplashOverlay> createState() => _LaunchSplashOverlayState();
}

class _LaunchSplashOverlayState extends State<LaunchSplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF04100B), Color(0xFF071A12), Color(0xFF020504)],
            ),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _controller.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _SplashGlow(
                    alignment: const Alignment(0.88, -0.92),
                    color: const Color(0xFF61FFB6).withValues(alpha: 0.34),
                    size: 260,
                    dx: math.sin(progress * math.pi * 2) * 18,
                    dy: math.cos(progress * math.pi * 2) * 14,
                  ),
                  _SplashGlow(
                    alignment: const Alignment(-0.92, 0.94),
                    color: const Color(0xFF67B8FF).withValues(alpha: 0.22),
                    size: 300,
                    dx: math.cos(progress * math.pi * 2) * 20,
                    dy: math.sin(progress * math.pi * 2) * 16,
                  ),
                  _SplashGlow(
                    alignment: const Alignment(0.08, 0.08),
                    color: const Color(0xFFBEFFF0).withValues(alpha: 0.12),
                    size: 220,
                    dx: math.sin(progress * math.pi * 4) * 8,
                    dy: math.cos(progress * math.pi * 4) * 8,
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SplashPainter(progress: progress),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Transform.translate(
                            offset: Offset(
                              0,
                              math.sin(progress * math.pi * 2) * -4,
                            ),
                            child: _HeroPulse(progress: progress),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            '石头音乐',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  height: 1.04,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '让曲库、灵感和情绪一起流动',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: const Color(0xFFB9D8CD),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.4,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Container(
                                width: 88,
                                height: 2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0x0051FFD0),
                                      Color(0xFF51FFD0),
                                      Color(0x0051FFD0),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'BUILDING YOUR NEXT SESSION',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: const Color(0xFF7FA594),
                                      letterSpacing: 1.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 34),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SplashGlow extends StatelessWidget {
  const _SplashGlow({
    required this.alignment,
    required this.color,
    required this.size,
    required this.dx,
    required this.dy,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double dx;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPulse extends StatelessWidget {
  const _HeroPulse({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scale = 1 + (math.sin(progress * math.pi * 2) * 0.02);
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            Container(
              width: 162,
              height: 162,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF58FFD1).withValues(alpha: 0.28),
                ),
              ),
            ),
            Transform.rotate(
              angle: progress * math.pi * 2,
              child: Container(
                width: 184,
                height: 184,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFF6DFFD8).withValues(alpha: 0.8),
                      const Color(0xFF6DFFD8).withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.22, 0.44, 1.0],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final phase = (progress * math.pi * 2) + index * 0.65;
                final height = 34 + ((math.sin(phase) + 1) * 18);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    width: 10,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFB7FFF1),
                          index.isEven
                              ? const Color(0xFF52FFCB)
                              : const Color(0xFF6AB8FF),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF51FFD0).withValues(alpha: 0.2),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  const _SplashPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF8AC6AF).withValues(alpha: 0.08)
      ..strokeWidth = 1;

    final path = Path();
    final baseY = size.height * 0.7;
    for (var i = 0; i < 4; i++) {
      path.reset();
      final yOffset = i * 18.0;
      path.moveTo(0, baseY + yOffset);
      for (double x = 0; x <= size.width; x += 8) {
        final y =
            baseY +
            yOffset +
            math.sin((x / size.width * math.pi * 2) + progress * math.pi * 2) *
                (8 + i * 3);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, gridPaint);
    }

    final sparkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFB8FFF0).withValues(alpha: 0.55);
    for (var i = 0; i < 10; i++) {
      final dx =
          (size.width * 0.18) +
          i * size.width * 0.08 +
          math.sin(progress * math.pi * 2 + i) * 6;
      final dy =
          size.height * 0.26 +
          math.cos(progress * math.pi * 2 + i * 0.5) * 14 +
          i * 10;
      canvas.drawCircle(Offset(dx, dy), i.isEven ? 1.4 : 1, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
