import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/loading_indicator.dart';
import 'share_invite_screen.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _emailController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;
  bool _isGenerating = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _firestoreService.sendInvite(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent!')),
        );
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateLinkAndShare() async {
    setState(() => _isGenerating = true);
    try {
      final id = await _firestoreService.generateInviteId();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShareInviteScreen(inviteId: id)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating link: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invite Family Member')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Address'),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const LoadingIndicator()
                : PrimaryButton(
                    text: 'Send Invite',
                    onPressed: _sendInvite,
                  ),
            const SizedBox(height: 12),
            _isGenerating
                ? const LoadingIndicator()
                : OutlinedButton.icon(
                    onPressed: _generateLinkAndShare,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Generate link / QR / Share'),
                  ),
          ],
        ),
      ),
    );
  }
}
 