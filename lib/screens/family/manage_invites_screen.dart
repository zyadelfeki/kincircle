import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'accept_invite_screen.dart';
import '../../utils/constants.dart';

class ManageInvitesScreen extends StatelessWidget {
  const ManageInvitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Invites')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('invite_events')
            .orderBy('timestamp', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 48, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('No invite activity yet',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                        'Accept or decline an invite to see events here.',
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final inviteId = data['inviteId'] as String? ?? '';
              final event = data['event'] as String? ?? '';
              final uid = data['uid'] as String? ?? '';
              final ts = data['timestamp'];
              final tsText = ts == null
                  ? ''
                  : (ts is Timestamp
                      ? ts.toDate().toLocal().toString()
                      : ts.toString());
              return ListTile(
                title: Text('$event · $inviteId'),
                subtitle: Text(uid.isEmpty ? '' : uid),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: inviteId));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite ID copied')),
                    );
                  }
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        tsText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'open') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AcceptInviteScreen(inviteId: inviteId),
                            ),
                          );
                        } else if (value == 'copy') {
                          Clipboard.setData(ClipboardData(text: inviteId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invite ID copied')),
                          );
                        } else if (value == 'share') {
                          SharePlus.instance.share(
                            ShareParams(
                              text:
                                  'Join my family circle on KinCircle: https://kincircle-live.web.app/invite/$inviteId',
                            ),
                          );
                        } else if (value == 'copylink') {
                          final url = '${AppConstants.inviteLinkBase}$inviteId';
                          Clipboard.setData(ClipboardData(text: url));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invite link copied')),
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                            value: 'open', child: Text('Open invite')),
                        PopupMenuItem(
                            value: 'share', child: Text('Share invite')),
                        PopupMenuItem(value: 'copy', child: Text('Copy ID')),
                        PopupMenuItem(
                            value: 'copylink', child: Text('Copy link')),
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
