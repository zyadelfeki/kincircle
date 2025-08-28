import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatyBackground extends StatefulWidget {
  final List<Color> gradientColors;
  final double intensity; // 0..1 controls blob opacity
  final int blobCount;

  const FloatyBackground({
    super.key,
    this.gradientColors = const [Color(0xFFEBF3FF), Color(0xFFE6FFF4)],
    this.intensity = 0.6,
    this.blobCount = 6,
  });

  @override
  State<FloatyBackground> createState() => _FloatyBackgroundState();
}

class _FloatyBackgroundState extends State<FloatyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Blob> _blobs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    final rnd = math.Random(42);
    _blobs = List.generate(widget.blobCount, (i) {
      final start = Offset(rnd.nextDouble(), rnd.nextDouble());
      final dx = (rnd.nextDouble() - 0.5) * 0.2;
      final dy = (rnd.nextDouble() - 0.5) * 0.2;
      final radius = 120.0 + rnd.nextDouble() * 140.0;
      final phase = rnd.nextDouble() * 2 * math.pi;
      return _Blob(start: start, delta: Offset(dx, dy), radius: radius, phase: phase);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _FloatyPainter(
            t: _controller.value,
            blobs: _blobs,
            colors: widget.gradientColors,
            intensity: widget.intensity,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _Blob {
  final Offset start;
  final Offset delta;
  final double radius;
  final double phase;
  const _Blob({required this.start, required this.delta, required this.radius, required this.phase});
}

class _FloatyPainter extends CustomPainter {
  final double t;
  final List<_Blob> blobs;
  final List<Color> colors;
  final double intensity;

  _FloatyPainter({required this.t, required this.blobs, required this.colors, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    // Gradient background
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // Floaty blobs
    for (final b in blobs) {
      final progress = (t + b.phase / (2 * math.pi)) % 1.0;
      final offset = b.start + b.delta * math.sin(progress * 2 * math.pi);
      final center = Offset(offset.dx * size.width, offset.dy * size.height);
      final blur = b.radius * 0.6;
      final blobPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.20 * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
      canvas.drawCircle(center, b.radius, blobPaint);
    }

    // Subtle vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.05)],
      ).createShader(Rect.fromCircle(center: rect.center, radius: size.longestSide));
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant _FloatyPainter oldDelegate) => oldDelegate.t != t;
}
