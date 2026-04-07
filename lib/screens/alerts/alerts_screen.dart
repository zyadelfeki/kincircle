import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../widgets/nav_shell.dart';
import 'alert_details_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  bool _showUnreadOnly = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs =
      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Please sign in.';
        });
        return;
      }

      Query<Map<String, dynamic>> query = _firestore
          .collection('alerts')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(100);
      if (_showUnreadOnly) {
        query = query.where('seen', isEqualTo: false);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _docs = snapshot.docs;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Check your connection or permissions.';
      });
    }
  }

  Future<void> _markRead(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    await doc.reference.set({'seen': true}, SetOptions(merge: true));
    _load();
  }

  Future<void> _markAllRead() async {
    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in _docs) {
      final bool seen = doc.data()['seen'] as bool? ?? false;
      if (!seen) {
        batch.set(doc.reference, {'seen': true}, SetOptions(merge: true));
      }
    }
    await batch.commit();
    _load();
  }

  Widget _loadingView() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (_, int index) {
        return Shimmer.fromColors(
          baseColor: KinCirclePalette.surfaceAlt,
          highlightColor: KinCirclePalette.border,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }

  Widget _errorView() {
    return _ErrorState(
      title: 'Unable to load alerts',
      message: _error ?? 'Check your connection or permissions.',
      onRetry: _load,
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined, color: KinCirclePalette.textMuted, size: 48),
            const SizedBox(height: 10),
            Text(
              _showUnreadOnly ? 'No unread alerts' : 'No alerts yet',
              style: KinCircleTypography.cardTitle16(),
            ),
            const SizedBox(height: 6),
            Text(
              'You are all caught up.',
              style: KinCircleTypography.body14(color: KinCirclePalette.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listView() {
    if (_docs.isEmpty) return _emptyView();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              FilterChip(
                selected: _showUnreadOnly,
                selectedColor: KinCirclePalette.accent.withValues(alpha: 0.25),
                label: Text(
                  'Unread only',
                  style: KinCircleTypography.caption12(
                    color: _showUnreadOnly ? KinCirclePalette.accent : KinCirclePalette.textMuted,
                  ),
                ),
                onSelected: (bool value) {
                  setState(() => _showUnreadOnly = value);
                  _load();
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: _markAllRead,
                child: const Text('Mark all read'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _docs.length,
            itemBuilder: (_, int index) {
              final QueryDocumentSnapshot<Map<String, dynamic>> doc = _docs[index];
              final Map<String, dynamic> data = doc.data();
              final String title = data['title'] as String? ?? 'Alert';
              final String message = data['message'] as String? ?? '';
              final bool seen = data['seen'] as bool? ?? false;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: KinCirclePalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KinCirclePalette.border, width: 1),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AlertDetailsScreen(alertId: doc.id, alertData: data),
                      ),
                    );
                  },
                  leading: Icon(
                    Icons.notification_important_outlined,
                    color: seen ? KinCirclePalette.textMuted : KinCirclePalette.accent,
                  ),
                  title: Text(title, style: KinCircleTypography.body14(weight: FontWeight.w600)),
                  subtitle: Text(
                    message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: KinCircleTypography.caption12(color: KinCirclePalette.textMuted),
                  ),
                  trailing: seen
                      ? null
                      : TextButton(
                          onPressed: () => _markRead(doc),
                          child: const Text('Read'),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = _loadingView();
    } else if (_error != null) {
      body = _errorView();
    } else {
      body = _listView();
    }

    return NavShell(
      currentIndex: 3,
      title: 'Alerts',
      body: body,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFF1E2440),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFF00C9A7),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8A8FA8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C9A7),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
