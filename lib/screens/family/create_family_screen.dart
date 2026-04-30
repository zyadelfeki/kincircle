import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../services/firestore_service.dart';
import '../../widgets/nav_shell.dart';

class CreateFamilyScreen extends StatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  State<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends State<CreateFamilyScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _loading = false;

  Future<void> _createCircle() async {
    setState(() => _loading = true);
    try {
      await _firestoreService.createFamily(name: 'My Circle');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/invite');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create circle')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _joinWithCode() async {
    if (!mounted) return;
    final TextEditingController codeController = TextEditingController();
    final palette = KinCirclePalette.of(context);
    final String? code = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.surface,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Join with invite code',
                style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: KinCircleDecorations.input(palette),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: codeController,
                  style: KinCircleTypography.body14(color: palette.textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter invite code',
                    hintStyle: KinCircleTypography.body14(color: palette.textMuted),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: KinCircleButtons.primary(),
                onPressed: () => Navigator.of(ctx).pop(codeController.text.trim()),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );
    codeController.dispose();
    if (code == null || code.isEmpty) return;
    if (!mounted) return;
    Navigator.of(context).pushNamed('/accept-invite', arguments: {'inviteId': code});
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return NavShell(
      currentIndex: 1,
      title: 'Create Circle',
      body: Center(
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
                child: Icon(Icons.shield_moon_rounded, color: palette.accent, size: 34),
              ),
              const SizedBox(height: 20),
              Text(
                "You're not in a Circle yet",
                style: KinCircleTypography.heading22(color: palette.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Create a new family circle or join one with an invite code.',
                style: KinCircleTypography.body14(color: palette.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                style: KinCircleButtons.primary(),
                onPressed: _loading ? null : _createCircle,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create a Circle'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: KinCircleButtons.secondary(),
                onPressed: _joinWithCode,
                child: const Text('Join with Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
