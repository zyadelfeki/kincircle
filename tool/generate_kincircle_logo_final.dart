import 'dart:io';
import 'dart:math' as math;

void main() async {
  const size = 1024.0;
  const radius = size * 0.35; // 358.4 px
  const strokeWidth = size * 0.18; // 184.3 px (~18% of diameter)

  final centerX = size / 2;
  final centerY = size / 2;

  final leftCenterX = centerX - radius * 0.42;
  final leftCenterY = centerY + radius * 0.18;

  final rightCenterX = centerX + radius * 0.42;
  final rightCenterY = centerY - radius * 0.18;

  final overlapRadius = radius * 0.38;
  final cutThickness = strokeWidth * 0.55;

  final svg = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="${size.toInt()}" height="${size.toInt()}" viewBox="0 0 ${size.toInt()} ${size.toInt()}" xmlns="http://www.w3.org/2000/svg" version="1.1">
  <defs>
    <linearGradient id="tealGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1BDEAE" />
      <stop offset="100%" stop-color="#2DD8B4" />
    </linearGradient>
    <linearGradient id="blueGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0D9FE8" />
      <stop offset="100%" stop-color="#1B8FDC" />
    </linearGradient>
    <linearGradient id="overlapGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#22D3C5" stop-opacity="0.85" />
      <stop offset="100%" stop-color="#1A9FE7" stop-opacity="0.85" />
    </linearGradient>

    <mask id="spiralCutLeft">
      <rect width="100%" height="100%" fill="white" />
      <circle cx="$rightCenterX" cy="$rightCenterY" r="$overlapRadius" fill="black" />
    </mask>

    <mask id="spiralCutRight">
      <rect width="100%" height="100%" fill="white" />
      <circle cx="$leftCenterX" cy="$leftCenterY" r="$overlapRadius" fill="black" />
    </mask>
  </defs>

  <circle cx="$leftCenterX" cy="$leftCenterY" r="$radius" fill="none" stroke="url(#tealGradient)" stroke-width="$strokeWidth" stroke-linecap="round" mask="url(#spiralCutLeft)" opacity="0.98" />

  <circle cx="$rightCenterX" cy="$rightCenterY" r="$radius" fill="none" stroke="url(#blueGradient)" stroke-width="$strokeWidth" stroke-linecap="round" mask="url(#spiralCutRight)" opacity="0.98" />

  <circle cx="$centerX" cy="$centerY" r="$overlapRadius" fill="url(#overlapGradient)" opacity="0.7" />

  <path d="${_spiralHighlightPath(centerX, centerY, radius, strokeWidth)}" fill="none" stroke="white" stroke-width="${strokeWidth * 0.2}" stroke-linecap="round" stroke-opacity="0.5" />
</svg>
''';

  final outputPath = 'assets/logo/kincircle_logo_final.svg';
  final file = File(outputPath);
  await file.create(recursive: true);
  await file.writeAsString(svg);

  stdout.writeln('✅ KinCircle hybrid logo SVG generated at $outputPath');
}

String _spiralHighlightPath(double centerX, double centerY, double radius, double strokeWidth) {
  final sweep = 1.2; // radians
  final startAngleLeft = math.pi * 0.65;
  final endAngleLeft = startAngleLeft + sweep;

  final startAngleRight = -math.pi * 0.2;
  final endAngleRight = startAngleRight + sweep;

  final leftStartX = centerX - radius * 0.45 * math.cos(startAngleLeft);
  final leftStartY = centerY + radius * 0.52 * math.sin(startAngleLeft);
  final leftEndX = centerX - radius * 0.38 * math.cos(endAngleLeft);
  final leftEndY = centerY + radius * 0.65 * math.sin(endAngleLeft);

  final rightStartX = centerX + radius * 0.58 * math.cos(startAngleRight);
  final rightStartY = centerY - radius * 0.52 * math.sin(startAngleRight);
  final rightEndX = centerX + radius * 0.42 * math.cos(endAngleRight);
  final rightEndY = centerY - radius * 0.65 * math.sin(endAngleRight);

  return 'M ${leftStartX.toStringAsFixed(2)} ${leftStartY.toStringAsFixed(2)} '
      'Q ${centerX - strokeWidth * 0.8} ${centerY + strokeWidth * 1.4} ${leftEndX.toStringAsFixed(2)} ${leftEndY.toStringAsFixed(2)} '
      'M ${rightStartX.toStringAsFixed(2)} ${rightStartY.toStringAsFixed(2)} '
      'Q ${centerX + strokeWidth * 0.8} ${centerY - strokeWidth * 1.4} ${rightEndX.toStringAsFixed(2)} ${rightEndY.toStringAsFixed(2)}';
}
