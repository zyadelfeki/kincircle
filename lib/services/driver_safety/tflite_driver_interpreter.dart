import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'interpreter.dart';

class TfliteDriverInterpreter implements DriverInterpreter {
  final tfl.Interpreter _inner;

  TfliteDriverInterpreter._(this._inner);

  static Future<TfliteDriverInterpreter> fromAsset(String assetPath) async {
    final interpreter = await tfl.Interpreter.fromAsset(assetPath);
    return TfliteDriverInterpreter._(interpreter);
  }

  @override
  List<double> run(List<double> features) {
    // Expecting input shape [1, N] and output shape [1, 3]
    final input = [features.map((e) => e.toDouble()).toList()];
    final output = [List<double>.filled(3, 0.0)];
    try {
      _inner.run(input, output);
      return output[0];
    } catch (_) {
      // Try resizing tensors as a fallback
      try {
        _inner.resizeInputTensor(0, [1, features.length]);
        _inner.allocateTensors();
        _inner.run(input, output);
        return output[0];
      } catch (e) {
        // On failure, return zeros to avoid crashing the app
        return [0.0, 0.0, 0.0];
      }
    }
  }
}
