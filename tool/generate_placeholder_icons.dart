import 'dart:io';
import 'package:image/image.dart' as img;

Future<void> main() async {
  final dir = Directory('assets/icon');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  // 1024x1024 master icon: white background with blue ring and inner white circle
  final icon1024 = img.Image(width: 1024, height: 1024);
  // Colors
  final white = img.ColorRgb8(255, 255, 255);
  final blue = img.ColorRgb8(0x19, 0x76, 0xD2);
  // White background
  img.fill(icon1024, color: white);
  // Blue ring (#1976D2): draw filled blue circle then carve white inner circle
  const cx = 512, cy = 512;
  const outerR = 450;
  const innerR = 410;
  img.fillCircle(
    icon1024,
    x: cx,
    y: cy,
    radius: outerR,
    color: blue,
  );
  img.fillCircle(
    icon1024,
    x: cx,
    y: cy,
    radius: innerR,
    color: white,
  );
  // Simple compass-pin glyph in center: blue circle with small tail
  const glyphR = 280;
  img.fillCircle(
    icon1024,
    x: cx,
    y: cy - 40,
    radius: glyphR,
    color: blue,
  );
  // Tail (triangle)
  final points = [
    img.Point(cx - 60, cy + 50),
    img.Point(cx + 60, cy + 50),
    img.Point(cx, cy + 230),
  ];
  img.fillPolygon(
    icon1024,
    vertices: points,
    color: blue,
  );

  final png1024 = img.encodePng(icon1024);
  await File('assets/icon/kincircle_icon_1024.png').writeAsBytes(png1024);

  // 512x512 foreground icon: transparent with same glyph only
  final fg = img.Image(width: 512, height: 512);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  const fcx = 256, fcy = 256;
  const fgR = 150;
  img.fillCircle(
    fg,
    x: fcx,
    y: fcy - 20,
    radius: fgR,
    color: blue,
  );
  final fpoints = [
    img.Point(fcx - 35, fcy + 30),
    img.Point(fcx + 35, fcy + 30),
    img.Point(fcx, fcy + 140),
  ];
  img.fillPolygon(
    fg,
    vertices: fpoints,
    color: blue,
  );
  final pngFg = img.encodePng(fg);
  await File('assets/icon/kincircle_icon_foreground.png').writeAsBytes(pngFg);

  // Basic sanity output
  stdout.writeln('Wrote assets/icon/kincircle_icon_1024.png');
  stdout.writeln('Wrote assets/icon/kincircle_icon_foreground.png');
}
