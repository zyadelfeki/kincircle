import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main(List<String> args) async {
  const size = 1024;
  final image = img.Image(width: size, height: size);

  // Transparent background
  img.fill(image, color: img.ColorUint8.rgba(0, 0, 0, 0));

  final cx = size ~/ 2;
  final cy = size ~/ 2;

  // Colors
  final white = img.ColorUint8.rgba(255, 255, 255, 255);
  final trustBlue = img.ColorUint8.rgba(0x2E, 0x86, 0xAB, 255);
  final calmTeal = img.ColorUint8.rgba(0xA2, 0xDE, 0xE5, 255);
  final safeGreen = img.ColorUint8.rgba(0x5F, 0xB4, 0x9C, 255);

  // Helper to draw a filled circle (anti-aliased-ish by oversampling stamps)
  void fillCircle(int x, int y, int r, img.Color color) {
    img.fillCircle(image, x: x, y: y, radius: r, color: color);
  }

  // Helper to draw a stroked arc by stamping small filled circles along path
  void drawArcStroke({
    required int x,
    required int y,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    required double strokeWidth,
  required img.Color color,
  }) {
    final step = 1.0 / (radius * 2); // angle step ~ sub-degree depending on radius
    final rStamp = (strokeWidth / 2).round();
    for (double t = 0; t <= 1.0; t += step) {
      final ang = startAngle + sweepAngle * t;
      final px = (x + radius * math.cos(ang)).round();
      final py = (y + radius * math.sin(ang)).round();
      fillCircle(px, py, rStamp, color);
    }
  }

  // 1) White background circle
  fillCircle(cx, cy, size ~/ 2, white);

  // 2) Blue ring (stroke only): draw outer circle in blue, then inner circle in white
  const ringStroke = 36.0;
  final outerRingR = size / 2 - ringStroke / 2;
  fillCircle(cx, cy, (outerRingR + ringStroke / 2).round(), trustBlue);
  fillCircle(cx, cy, (outerRingR - ringStroke / 2).round(), white);

  // 3) KinCircle arcs (nearly full circle, leave small gap for rounded feel)
  // Use -90° start (top). Image Y grows downward; sin/cos mapping is fine.
  const gapFactor = 0.03; // 3% gap
  final sweep = 2 * math.pi * (1 - gapFactor);
  final start = -math.pi / 2;

  // Outer arc: radius 382, stroke 40
  drawArcStroke(
    x: cx,
    y: cy,
    radius: 382,
    startAngle: start,
    sweepAngle: sweep,
    strokeWidth: 40,
    color: trustBlue,
  );

  // Inner arc: radius 302, stroke 32
  drawArcStroke(
    x: cx,
    y: cy,
    radius: 302,
    startAngle: start,
    sweepAngle: sweep,
    strokeWidth: 32,
    color: calmTeal,
  );

  // 4) Center dot and accent dots
  fillCircle(cx, cy, 60, safeGreen);
  // accents with ~60% opacity: approximate by blending over white; keep solid for simplicity
  fillCircle(512, 300, 8, img.ColorUint8.rgba(0x5F, 0xB4, 0x9C, (0.6 * 255).round()));
  fillCircle(650, 450, 8, safeGreen);
  fillCircle(374, 450, 8, safeGreen);
  fillCircle(512, 724, 8, safeGreen);

  final png = img.encodePng(image);
  final out = File('assets/icon/kin_arc_launcher_icon.png');
  await out.create(recursive: true);
  await out.writeAsBytes(png);
  stdout.writeln('Wrote: ${out.path} (${png.length} bytes)');
}
