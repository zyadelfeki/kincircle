import 'package:flutter/material.dart';
import 'driving_mode_screen.dart';
import 'safety_report_screen.dart';

class DriverSafetyHubScreen extends StatelessWidget {
  const DriverSafetyHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Safety')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.directions_car_filled_rounded),
              label: const Text('Start a Drive'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DrivingModeScreen()),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.summarize_rounded),
              label: const Text('View Safety Report'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SafetyReportScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
