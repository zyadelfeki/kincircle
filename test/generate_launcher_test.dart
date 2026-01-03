import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kincircle/utils/theme.dart';
import 'package:flutter/rendering.dart';

class _IconBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final bgPaint = Paint()..color = Colors.white..isAntiAlias = true;
    canvas.drawCircle(center, radius, bgPaint);
    final ringPaint = Paint()
  ..color = kinPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 56
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius - (ringPaint.strokeWidth / 2.0), ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generate kin_arc_launcher_icon.png (1024x1024)', (tester) async {
    const int size = 1024;
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: size.toDouble(),
              height: size.toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _IconBackgroundPainter()),
                  Center(
                    child: SizedBox(
                      width: size * 0.70,
                      height: size * 0.70,
                      child: SvgPicture.asset(
                        'assets/icon/kin_arc_final.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final boundary = tester.renderObject(find.byKey(key)) as RenderRepaintBoundary;
  final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final outFile = File('assets/icon/kin_arc_launcher_icon.png');
    await outFile.writeAsBytes(byteData!.buffer.asUint8List());

    expect(await outFile.exists(), true);
  }, skip: true);
}
