import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../services/telemetry_service.dart';

class AcceptInviteScreen extends StatefulWidget {
  const AcceptInviteScreen({super.key, required this.inviteId});

  final String inviteId;

  @override
  State<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends State<AcceptInviteScreen> {
  late Future<Map<String, dynamic>> _inviteFuture;
  bool _submitting = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _inviteFuture = _fetchInvite();
  }

  Future<Map<String, dynamic>> _fetchInvite() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('invites')
          .doc(widget.inviteId)
          .get();
      if (!snap.exists) {
        throw Exception('Invite does not exist or has already been used.');
      }
      return snap.data() as Map<String, dynamic>;
    } catch (e) {
      _loadError = e;
      rethrow;
    }
  }

  Future<void> _handleAccept(String familyId) async {
    try {
      setState(() => _submitting = true);
      await FirestoreService().acceptInvite(inviteId: widget.inviteId);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family Invitation')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _inviteFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error loading invite',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('$_loadError'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadError = null;
                          _inviteFuture = _fetchInvite();
                        });
                      },
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Invite not found.'));
          }
          final data = snapshot.data!;
          final familyId = data['familyId'] as String? ?? '';
          final inviterName = data['inviterName'] as String? ?? 'Someone';

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('families')
                .doc(familyId)
                .get(),
            builder: (context, famSnap) {
              if (famSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (famSnap.hasError ||
                  !famSnap.hasData ||
                  !famSnap.data!.exists) {
                return const Center(child: Text('Family not found'));
              }
              final famData = famSnap.data!.data() as Map<String, dynamic>;
              final familyName = famData['name'] as String? ?? 'Family';

              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '$inviterName has invited you to join the "$familyName" circle.',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitting
                                ? null
                                : () => _handleAccept(familyId),
                            child: const Text('Accept'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () async {
                                    final nav = Navigator.of(context);
                                    try {
                                      await TelemetryService().logInviteEvent(
                                        inviteId: widget.inviteId,
                                        event: 'declined',
                                      );
                                    } catch (_) {}
                                    if (!mounted) return;
                                    nav.pop();
                                  },
                            child: const Text('Decline'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
