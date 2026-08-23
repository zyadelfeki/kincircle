import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const int size = 1024;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

  // Background: white circle
  final bgPaint = Paint()
    ..color = Colors.white
    ..isAntiAlias = true;
  canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.0, bgPaint);

  // Draw a simple arc mark resembling the KinCircle logo without SVG dependency
  final arcPaint = Paint()
    ..color = const Color(0xFF1976D2)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 140
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final arcRect = Rect.fromLTWH(size * 0.18, size * 0.18, size * 0.64, size * 0.64);
  canvas.drawArc(arcRect, -0.6, 1.2, false, arcPaint);

  // Finish and write PNG
  final img = await recorder.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  final outFile = File('assets/icon/kin_arc_launcher_icon.png');
  await outFile.writeAsBytes(bytes!.buffer.asUint8List());
  // Exit immediately
  SystemNavigator.pop();
}
