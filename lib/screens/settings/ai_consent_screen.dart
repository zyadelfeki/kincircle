import 'package:flutter/material.dart';
import '../../services/consent_service.dart';

class AiConsentScreen extends StatelessWidget {
  const AiConsentScreen({super.key});

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
              'What Are Smart Alerts?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
                'Smart Alerts learn your family\'s usual places and times (like school hours) by analysing past 30 days of location data. When something unusual happens — for example a phone leaves school late at night — KinCircle can send you a real-time alert.'),
            const SizedBox(height: 16),
            const Text(
              'How We Use Your Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
                '• Your raw location history never leaves Google Cloud and is never shared with advertisers.\n• The AI model converts your history into anonymous patterns to understand routines.\n• You can turn Smart Alerts off at any time and delete your data.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  await ConsentService().setConsentGiven();
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                child: const Text('I Agree & Opt-In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
