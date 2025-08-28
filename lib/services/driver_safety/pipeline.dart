part of 'driver_safety_service.dart';

class DriverSensorPipeline {
  final int windowSize; // samples per window
  final int sampleHz;
  final List<double> _ax = [], _ay = [], _az = [];
  final List<double> _gx = [], _gy = [], _gz = [];

  DriverSensorPipeline({required this.windowSize, required this.sampleHz});

  void addAccel(double x, double y, double z) {
    _push(_ax, x);
    _push(_ay, y);
    _push(_az, z);
  }

  void addGyro(double x, double y, double z) {
    _push(_gx, x);
    _push(_gy, y);
    _push(_gz, z);
  }

  bool get ready => _ax.length >= windowSize && _gx.length >= windowSize;

  void _push(List<double> list, double v) {
    list.add(v);
    if (list.length > windowSize) list.removeAt(0);
  }

  List<double> popWindow() {
    if (!ready) return [];
    // Basic feature extraction: mean and std for each axis
    final feats = <double>[];
    for (final s in [_ax, _ay, _az, _gx, _gy, _gz]) {
      final m = _mean(s);
      final sd = _std(s, m);
      feats..add(m)..add(sd);
    }
    return feats;
  }

  double _mean(List<double> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  double _std(List<double> v, double m) {
    if (v.isEmpty) return 0;
    var sum = 0.0;
    for (final x in v) {
      final d = x - m;
      sum += d * d;
    }
    return sqrt(sum / v.length);
  }
}
