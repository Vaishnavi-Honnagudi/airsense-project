import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dynamic, hardware-accelerated animated weather background widget for AirSense.
/// Supports Delhi Smog/Haze, Rain, Sunny/Clear, and Night conditions.
enum WeatherAnimationType {
  smogHaze,
  rain,
  sunny,
  night,
}

class AnimatedWeatherBackground extends StatefulWidget {
  final WeatherAnimationType animationType;
  final Widget child;
  final BorderRadius? borderRadius;
  final double height;

  const AnimatedWeatherBackground({
    super.key,
    required this.animationType,
    required this.child,
    this.borderRadius,
    this.height = 240,
  });

  @override
  State<AnimatedWeatherBackground> createState() => _AnimatedWeatherBackgroundState();
}

class _AnimatedWeatherBackgroundState extends State<AnimatedWeatherBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(24),
      child: Stack(
        children: [
          // Base atmospheric gradient layer
          _buildBaseGradient(),

          // Dynamic animated weather particle layer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _WeatherParticlePainter(
                    progress: _controller.value,
                    type: widget.animationType,
                  ),
                );
              },
            ),
          ),

          // Content child on top
          widget.child,
        ],
      ),
    );
  }

  Widget _buildBaseGradient() {
    List<Color> colors;
    switch (widget.animationType) {
      case WeatherAnimationType.rain:
        colors = [
          const Color(0xFF0F172A),
          const Color(0xFF1E3A5F),
          const Color(0xFF0F2027),
        ];
        break;
      case WeatherAnimationType.sunny:
        colors = [
          const Color(0xFF1E293B),
          const Color(0xFF334155),
          const Color(0xFF78350F).withValues(alpha: 0.9),
        ];
        break;
      case WeatherAnimationType.night:
        colors = [
          const Color(0xFF020617),
          const Color(0xFF0F172A),
          const Color(0xFF1E1B4B),
        ];
        break;
      case WeatherAnimationType.smogHaze:
        // Signature Delhi atmospheric smog gradient: deep charcoal with warm amber smog haze
        colors = [
          const Color(0xFF0F172A),
          const Color(0xFF1E293B),
          const Color(0xFF451A03).withValues(alpha: 0.95),
        ];
        break;
    }

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
      ),
    );
  }
}

class _WeatherParticlePainter extends CustomPainter {
  final double progress;
  final WeatherAnimationType type;

  _WeatherParticlePainter({
    required this.progress,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    switch (type) {
      case WeatherAnimationType.rain:
        _paintRain(canvas, size);
        break;
      case WeatherAnimationType.sunny:
        _paintSunny(canvas, size);
        break;
      case WeatherAnimationType.night:
        _paintNight(canvas, size);
        break;
      case WeatherAnimationType.smogHaze:
        _paintSmog(canvas, size);
        break;
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    // 60 Vivid falling rain streaks with high visibility
    final dropPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.70)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const count = 55;
    for (int i = 0; i < count; i++) {
      final initialX = (i * 29.0) % size.width;
      final initialY = (i * 17.0) % size.height;
      final speed = 1.2 + (i % 4) * 0.4;

      final y = (initialY + progress * size.height * speed * 2.5) % (size.height + 60) - 30;
      final x = (initialX - progress * 50 * speed) % size.width;

      final dropLength = 16.0 + (i % 5) * 5.0;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 4.5, y + dropLength),
        dropPaint,
      );

      // Splash ripple when near bottom
      if (y > size.height - 35) {
        final ripplePaint = Paint()
          ..color = const Color(0xFF7DD3FC).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        final rippleR = (i % 3 + 1) * 3.0;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, size.height - 10), width: rippleR * 2, height: rippleR),
          ripplePaint,
        );
      }
    }
  }

  void _paintSmog(Canvas canvas, Size size) {
    // 1. Drifting atmospheric aerosol fog & particulate mist clouds
    final mistPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);

    const mistLayers = 5;
    for (int i = 0; i < mistLayers; i++) {
      final speed = 0.6 + (i * 0.2);
      final driftX = (progress * size.width * speed + (i * size.width / mistLayers)) % (size.width + 160) - 80;
      final y = size.height * 0.3 + (i * 24.0) + math.sin((progress * 2 * math.pi) + i) * 10;

      mistPaint.color = i % 2 == 0
          ? const Color(0xFFF59E0B).withValues(alpha: 0.20) // Warm amber smog cloud
          : const Color(0xFF94A3B8).withValues(alpha: 0.18); // Dense aerosol grey haze

      final radius = 55.0 + (i * 14.0);
      canvas.drawCircle(Offset(driftX, y), radius, mistPaint);
    }

    // 2. High-visibility PM2.5 / PM10 particulate dust motes drifting across the card
    final speckPaint = Paint()..style = PaintingStyle.fill;
    const speckCount = 35;
    for (int i = 0; i < speckCount; i++) {
      final speed = 0.8 + (i % 3) * 0.3;
      final dx = ((i * 37.0) + progress * size.width * speed) % size.width;
      final dy = ((i * 23.0) + math.cos(progress * math.pi * 2 + i) * 16) % size.height;
      final alpha = (0.35 + 0.35 * math.sin(progress * 2 * math.pi + i)).clamp(0.2, 0.85);

      speckPaint.color = (i % 3 == 0)
          ? const Color(0xFFFBBF24).withValues(alpha: alpha) // glowing amber dust
          : Colors.white.withValues(alpha: alpha); // bright airborne particle

      final r = (i % 4 == 0) ? 2.5 : 1.6;
      canvas.drawCircle(Offset(dx, dy), r, speckPaint);
    }
  }

  void _paintSunny(Canvas canvas, Size size) {
    // 1. Radiant glowing Sun in top right
    final sunCenter = Offset(size.width - 35, 25);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFBBF24).withValues(alpha: 0.65),
          const Color(0xFFF59E0B).withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 130));

    final pulse = 1.0 + 0.12 * math.sin(progress * 2 * math.pi);
    canvas.drawCircle(sunCenter, 110 * pulse, glowPaint);

    // 2. Rotating radiant sunbeams
    final rayPaint = Paint()
      ..color = const Color(0xFFFEF08A).withValues(alpha: 0.15)
      ..strokeWidth = 40
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    for (int i = 0; i < 5; i++) {
      final angle = (math.pi * 0.35) + (i * 0.22) + math.sin(progress * math.pi * 2) * 0.08;
      final end = Offset(
        sunCenter.dx - math.cos(angle) * 220,
        sunCenter.dy + math.sin(angle) * 220,
      );
      canvas.drawLine(sunCenter, end, rayPaint);
    }

    // 3. Floating sun dust motes
    final sunDust = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 20; i++) {
      final x = ((i * 43.0) + math.sin(progress * math.pi * 2 + i) * 20) % size.width;
      final y = ((i * 31.0) + progress * 40) % size.height;
      sunDust.color = const Color(0xFFFDE047).withValues(alpha: 0.45);
      canvas.drawCircle(Offset(x, y), 2.0, sunDust);
    }
  }

  void _paintNight(Canvas canvas, Size size) {
    // 1. Glowing Crescent Moon in top right
    final moonCenter = Offset(size.width - 45, 30);
    final moonGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: moonCenter, radius: 45));
    canvas.drawCircle(moonCenter, 40, moonGlow);

    final moonPaint = Paint()..color = const Color(0xFFF0F9FF);
    canvas.drawCircle(moonCenter, 16, moonPaint);
    final shadowPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(Offset(moonCenter.dx + 6, moonCenter.dy - 4), 14, shadowPaint);

    // 2. Sparkling twinkling stars
    final starPaint = Paint()..style = PaintingStyle.fill;
    const count = 35;
    for (int i = 0; i < count; i++) {
      final x = (i * 37.0) % size.width;
      final y = (i * 19.0) % (size.height * 0.85);
      final twinkle = 0.3 + 0.7 * math.sin((progress * 4 * math.pi) + (i * 1.8)).abs();
      starPaint.color = Colors.white.withValues(alpha: twinkle.clamp(0.2, 0.95));
      canvas.drawCircle(Offset(x, y), (i % 3 == 0) ? 2.2 : 1.4, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.type != type;
  }
}
