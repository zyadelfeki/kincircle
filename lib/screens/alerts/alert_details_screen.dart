import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/feedback_service.dart';

class AlertDetailsScreen extends StatelessWidget {
  final String alertId;
  final Map<String, dynamic>? alertData;

  const AlertDetailsScreen({super.key, required this.alertId, this.alertData});

  @override
  Widget build(BuildContext context) {
    if (alertData != null) {
      return _buildScaffold(context, alertData!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('alerts').doc(alertId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Alert not found'));
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          return _buildScaffold(context, data);
        },
      ),
    );
  }

  Scaffold _buildScaffold(BuildContext context, Map<String, dynamic> alert) {
    final message = alert['message'] as String? ?? 'Alert';
    final ts = alert['timestamp'] as Timestamp?;

    return Scaffold(
      appBar: AppBar(title: const Text('Alert Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (ts != null)
              Text('Time: ${ts.toDate()}',
                  style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.thumb_up),
                    label: const Text('This alert was helpful'),
                    onPressed: () async {
                      await _submitFeedback(context, true);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.thumb_down),
                    label: const Text('This was not useful'),
                    onPressed: () async {
                      await _submitFeedback(context, false);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitFeedback(BuildContext context, bool helpful) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be signed in to give feedback.')),
      );
      return;
    }
    try {
      await FeedbackService().submitAlertFeedback(
        alertId: alertId,
        userId: userId,
        helpful: helpful,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit feedback.')),
        );
      }
    }
  }
}
 