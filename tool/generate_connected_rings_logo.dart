import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Generates a PNG from the Connected Rings SVG logo
void main(List<String> args) async {
  // Ensure Flutter framework is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  const size = 1024;
  const svgPath = 'assets/logo/final_logo.svg';
  const outputPath = 'assets/logo/new_logo.png';
  
  try {
    print('Loading SVG from: $svgPath');
    
    // Read the SVG file
    final svgFile = File(svgPath);
    if (!await svgFile.exists()) {
      print('ERROR: SVG file not found at $svgPath');
      exit(1);
    }
    
    final svgString = await svgFile.readAsString();
    print('SVG loaded successfully');
    
    // Parse the SVG
    final pictureInfo = await svg.fromSvgString(svgString, svgString);
    print('SVG parsed successfully');
    
    // Create a picture recorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
    
    // Scale the SVG to fit the target size
    final scale = size / 1024.0; // SVG is designed at 1024x1024
    canvas.scale(scale);
    
    // Draw the SVG picture
    canvas.drawPicture(pictureInfo.picture);
    print('SVG rendered to canvas');
    
    // End recording and create image
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    print('Canvas converted to image');
    
    // Convert to byte data
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      print('ERROR: Failed to convert image to PNG bytes');
      exit(1);
    }
    
    // Save to file
    final pngBytes = byteData.buffer.asUint8List();
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(pngBytes);
    
    print('✅ Connected Rings logo PNG generated successfully!');
    print('📍 Output: $outputPath');
    print('📏 Size: ${size}x$size pixels');
    print('💾 File size: ${(pngBytes.length / 1024).toStringAsFixed(1)} KB');
    
  } catch (e, stackTrace) {
    print('❌ ERROR generating logo: $e');
    print('Stack trace: $stackTrace');
    exit(1);
  }
}
