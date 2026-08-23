import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kincircle/services/driver_safety/driver_safety_service.dart';
import 'package:kincircle/services/driver_safety/tflite_driver_interpreter.dart';

class DrivingModeScreen extends StatefulWidget {
  const DrivingModeScreen({super.key});

  @override
  State<DrivingModeScreen> createState() => _DrivingModeScreenState();
}

class _DrivingModeScreenState extends State<DrivingModeScreen> {
  DriverSafetyService? _service;
  bool _running = false;
  String _status = 'Idle';
  static const String _modelPath = 'assets/models/driver_safety.tflite';

  Future<void> _ensureHive() async {
    if (!Hive.isAdapterRegistered(0)) {
      await Hive.initFlutter();
    }
  }

  Future<void> _start() async {
    try {
      await _ensureHive();
      setState(() => _status = 'Starting…');
      // Preflight: ensure the TFLite model is bundled; otherwise show coming soon and bail early.
      final exists = await _assetExists(_modelPath);
      if (!exists) {
        if (!mounted) return;
        setState(() => _status = 'Driving mode is coming soon');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Driving mode is coming soon'),
          ),
        );
        return;
      }
      final service = DriverSafetyService(
        interpreterFactory: (asset) => TfliteDriverInterpreter.fromAsset(asset),
      );
      await service.start();
      if (!mounted) return;
      setState(() {
        _service = service;
        _running = true;
        _status = 'Driving… collecting data';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'Driving mode is coming soon');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driving mode is coming soon'),
        ),
      );
    }
  }

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _stop() async {
    setState(() => _status = 'Stopping…');
    await _service?.stop();
    setState(() {
      _running = false;
      _status = 'Drive ended';
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _running ? Colors.redAccent : Colors.greenAccent;
    final label = _running ? 'End Drive' : 'Start Drive';
    final icon = _running
        ? Icons.stop_circle_rounded
        : Icons.directions_car_filled_rounded;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Driving Mode'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                textStyle:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _running ? _stop : _start,
              icon: Icon(icon, size: 28),
              label: Text(label),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keep your eyes on the road. This runs entirely on-device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
