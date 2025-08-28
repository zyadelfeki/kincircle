import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/link_builder.dart';

class ShareInviteScreen extends StatelessWidget {
  final String inviteId;
  const ShareInviteScreen({super.key, required this.inviteId});

  @override
  Widget build(BuildContext context) {
    final url = buildInviteLink(inviteId);
    return Scaffold(
      appBar: AppBar(title: const Text('Share Invite')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Scan to join', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Center(
              child: QrImageView(
                data: url,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(url, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => SharePlus.instance.share(ShareParams(text: url)),
              icon: const Icon(Icons.ios_share),
              label: const Text('Share link'),
            ),
          ],
        ),
      ),
    );
  }
}
