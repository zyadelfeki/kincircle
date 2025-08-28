/// A tiny abstraction over the model interpreter so tests can stub it
/// without pulling in tflite_flutter package.
abstract class DriverInterpreter {
  /// Returns a list of 3 scores [brake, turn, accel]
  List<double> run(List<double> features);
}
