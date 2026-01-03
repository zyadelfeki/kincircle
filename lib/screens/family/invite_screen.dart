import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../services/pro_gating_service.dart';
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
      final nav = Navigator.of(context);
      // Quick preflight: ensure user has a family
      final hasFamily = await _firestoreService.hasCurrentFamily();
      if (!hasFamily) {
        if (!mounted) return;
        final goCreate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Create a Family First'),
            content: const Text(
                'To invite someone, create or join a family. You can create a new family now.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Not now')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create Family')),
            ],
          ),
        );
        if (goCreate == true && mounted) {
          nav.pushNamed('/create-family');
        }
        return;
      }
      // Enforce Free tier member limit before sending
  final famId = await _firestoreService.getCurrentFamilyId();
  if (!mounted) return;
  if (famId != null) {
        final allowed = await ProGatingService().ensureCanAddMember(context, famId);
        if (!allowed) return;
      }
      await _firestoreService.sendInvite(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Invitation sent. Your contact will see a link to join your family.')),
        );
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('We couldn’t send that invite. $msg'),
          action: SnackBarAction(
            label: 'Help',
            onPressed: () => Navigator.of(context).pushNamed('/help'),
          ),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateLinkAndShare() async {
    setState(() => _isGenerating = true);
    try {
      final nav = Navigator.of(context);
      final hasFamily = await _firestoreService.hasCurrentFamily();
      if (!hasFamily) {
        if (!mounted) return;
        final goCreate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Create a Family First'),
            content: const Text(
                'To generate an invite link, create or join a family. You can create a new family now.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Not now')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create Family')),
            ],
          ),
        );
        if (goCreate == true && mounted) {
          nav.pushNamed('/create-family');
        }
        return;
      }
  final famId = await _firestoreService.getCurrentFamilyId();
  if (!mounted) return;
  if (famId != null) {
        final allowed = await ProGatingService().ensureCanAddMember(context, famId);
        if (!allowed) return;
      }
      final id = await _firestoreService.generateInviteId();
      if (!mounted) return;
      nav.push(
        MaterialPageRoute(builder: (_) => ShareInviteScreen(inviteId: id)),
      );
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Couldn’t generate an invite link. $msg'),
          action: SnackBarAction(
            label: 'Help',
            onPressed: () => Navigator.of(context).pushNamed('/help'),
          ),
        ));
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
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/create-family'),
              child: const Text('Create a Family'),
            ),
          ],
        ),
      ),
    );
  }
}
