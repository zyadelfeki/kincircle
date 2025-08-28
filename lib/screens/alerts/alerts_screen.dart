import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'alert_details_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _showUnreadOnly = false;
  bool _marking = false;

  Query _buildQuery(String uid) {
    Query q = _firestore
        .collection('alerts')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(100);
    if (_showUnreadOnly) {
      q = q.where('seen', isEqualTo: false);
    }
    return q;
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    if (_marking) return;
    setState(() => _marking = true);
    try {
      final batch = _firestore.batch();
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if ((data['seen'] as bool?) == true) continue;
        batch.set(d.reference, {'seen': true}, SetOptions(merge: true));
      }
      await batch.commit();
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('No user')));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: FilterChip(
                label: const Text('Unread'),
                selected: _showUnreadOnly,
                onSelected: (v) => setState(() => _showUnreadOnly = v),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final err = snapshot.error;
            if (err is FirebaseException && err.code == 'failed-precondition') {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, size: 48),
                      const SizedBox(height: 12),
                      Text('Alerts index needed', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'We need to create a Firestore index to load alerts quickly. Tap Help for steps or try again later after deploying indexes.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/help'),
                        icon: const Icon(Icons.help_outline),
                        label: const Text('Help'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(_showUnreadOnly ? 'No unread alerts' : 'No alerts yet',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            );
          }
          return Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 8),
                  child: TextButton.icon(
                    onPressed: _marking ? null : () => _markAllAsRead(docs.cast<QueryDocumentSnapshot>()),
                    icon: const Icon(Icons.done_all),
                    label: Text(_marking ? 'Marking…' : 'Mark all as read'),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = docs[index];
                    final data = d.data() as Map<String, dynamic>? ?? {};
                    final title = data['title'] as String? ?? 'Alert';
                    final message = data['message'] as String? ?? '';
                    final seen = (data['seen'] as bool?) ?? false;
                    return ListTile(
                      leading: Icon(
                        Icons.notification_important,
                        color: seen ? Theme.of(context).hintColor : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(title),
                      subtitle: Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: seen ? null : TextButton(
                        onPressed: () => _markAllAsRead([d]),
                        child: const Text('Mark read'),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AlertDetailsScreen(alertId: d.id, alertData: data),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
