import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  // Create base image filled with deep navy
  var im = img.Image(width: size, height: size);
  im = img.fill(im, color: img.ColorRgb8(20, 30, 50));

  final cx = size ~/ 2;
  final cy = size ~/ 2;

  // Helper to approximate a filled circle with a polygon
  List<img.Point> circlePoints(int radius, {int steps = 180}) {
    final pts = <img.Point>[];
    for (int i = 0; i < steps; i++) {
      final t = (i / steps) * 2 * 3.141592653589793;
      final x = (cx + radius * Math.cos(t)).round();
      final y = (cy + radius * Math.sin(t)).round();
      pts.add(img.Point(x, y));
    }
    return pts;
  }

  // We don't have Math here; implement simple cos/sin via dart:math

  // Inner filled circle
  // Paint inner filled circle using flood fill after drawing boundary
  im = img.drawCircle(
    im,
    x: cx,
    y: cy,
    radius: 260,
    color: img.ColorRgb8(255, 255, 255),
  );
  im = img.floodFill(
    im,
    x: cx,
    y: cy,
    color: img.ColorRgb8(255, 255, 255),
  );

  // Small accent dot
  // Small accent dot: draw boundary and flood fill
  im = img.drawCircle(
    im,
    x: cx + 200,
    y: cy - 200,
    radius: 50,
    color: img.ColorRgb8(64, 140, 255),
  );
  im = img.floodFill(
    im,
    x: cx + 200,
    y: cy - 200,
    color: img.ColorRgb8(64, 140, 255),
  );

  // Export
  final outPath = 'assets/logo/launcher_generated.png';
  final outFile = File(outPath);
  outFile.createSync(recursive: true);
  outFile.writeAsBytesSync(img.encodePng(im));
  stdout.writeln('Generated $outPath (${im.width}x${im.height})');
}
