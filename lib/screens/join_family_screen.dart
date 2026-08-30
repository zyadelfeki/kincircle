import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../design/kincircle_screen_tokens.dart';
import '../services/firestore_service.dart';
import '../widgets/nav_shell.dart';

class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _familyName;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _joinFamily() async {
    await HapticFeedback.lightImpact();
    final String code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter an invite code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final String? familyId = await _firestoreService.getFamilyIdFromInvite(code);
      if (familyId == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Invalid or expired invite code';
        });
        return;
      }

      final Map<String, dynamic>? details =
          await _firestoreService.getFamilyDetails(familyId);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _familyName = details?['name'] as String?;
      });

      await _firestoreService.acceptInvite(inviteId: code);
      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed('/dashboard');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to join circle: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to join circle: $e';
      });
    }
  }

  void _pasteAndJoin() async {
    final ClipboardData? data = await Clipboard.getData('text/plain');
    final String? pasted = data?.text;
    if (pasted != null) {
      _codeController.text = pasted;
      _joinFamily();
    }
  }

  @override
  Widget build(BuildContext context) {
    return NavShell(
      currentIndex: 1,
      title: 'Join Circle',
      body: _body(),
    );
  }

  Widget _body() {
    final palette = KinCirclePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: palette.border, width: 1),
              ),
              child: Icon(Icons.group_add_rounded, color: palette.accent, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              'Join a Circle',
              style: KinCircleTypography.heading22(color: palette.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Enter an invite code to join a family circle.',
              style: KinCircleTypography.body14(color: palette.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            Container(
              decoration: KinCircleDecorations.input(palette),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter invite code',
                  hintStyle: KinCircleTypography.body14(color: palette.textMuted),
                ),
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                style: KinCircleTypography.body16(color: palette.textPrimary),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: KinCircleTypography.caption12(color: palette.error),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_familyName != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Joining: $_familyName',
                  style: KinCircleTypography.caption12(color: palette.success),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: KinCircleButtons.primary(),
              onPressed: _loading ? null : _joinFamily,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join Circle'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: KinCircleButtons.secondary(),
              onPressed: _pasteAndJoin,
              child: const Text('Paste & Join'),
            ),
          ],
        ),
      ),
    );
  }
}
