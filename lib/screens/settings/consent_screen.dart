import 'package:flutter/material.dart';
import '../../services/consent_service.dart';

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Alerts Consent')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What are Smart Alerts?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'KinCircle can learn your everyday routines from your location history '
              'so it only notifies you when something unusual happens. This means less '
              'notification fatigue and more peace of mind.',
            ),
            const SizedBox(height: 16),
            const Text(
              'How it works',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. The app stores your past 30 days of location events in an encrypted database.\n'
              '2. Our secure cloud model looks for patterns (e.g., typical school hours).\n'
              '3. If you go somewhere at an unusual time, the app sends an "Anomaly Alert".',
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await ConsentService().setConsentGiven();
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: const Text('I Agree – Enable Smart Alerts'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
