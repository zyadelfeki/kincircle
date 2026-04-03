import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../models/family.dart';
import '../../services/firestore_service.dart';
import '../../utils/link_builder.dart';
import '../../widgets/nav_shell.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = true;
  String? _error;
  String? _familyId;
  List<FamilyMember> _members = <FamilyMember>[];
  String? _inviteCode;

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
      final String? familyId = await _firestoreService.getCurrentFamilyId();
      if (familyId == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _familyId = null;
          _members = <FamilyMember>[];
        });
        return;
      }
      final Map<String, dynamic>? details =
          await _firestoreService.getFamilyDetails(familyId);
      final List<FamilyMember> members = (details?['members'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(FamilyMember.fromMap)
          .toList();
      if (!mounted) return;
      setState(() {
        _familyId = familyId;
        _members = members;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load family members';
      });
    }
  }

  Future<void> _openInviteOptions() async {
    try {
      final String code = _inviteCode ?? await _firestoreService.generateInviteId();
      if (!mounted) return;
      setState(() => _inviteCode = code);
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: KinCirclePalette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (BuildContext context) {
          final String link = buildInviteLink(code);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite Member', style: KinCircleTypography.cardTitle16()),
                  const SizedBox(height: 10),
                  Text(
                    'Share link or invite code with your family member.',
                    style: KinCircleTypography.caption12(color: KinCirclePalette.textMuted),
                  ),
                  const SizedBox(height: 14),
                  _sheetAction(
                    icon: Icons.share_rounded,
                    title: 'Share invite link',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await SharePlus.instance.share(
                        ShareParams(text: link),
                      );
                    },
                  ),
                  _sheetAction(
                    icon: Icons.copy_rounded,
                    title: 'Copy invite code',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied')),
                      );
                    },
                  ),
                  _sheetAction(
                    icon: Icons.sms_outlined,
                    title: 'Send via SMS',
                    onTap: () async {
                      Navigator.of(context).pop();
                      final Uri uri = Uri.parse('sms:?body=Join my KinCircle: $link');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                  _sheetAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Send via WhatsApp',
                    onTap: () async {
                      Navigator.of(context).pop();
                      final Uri uri = Uri.parse('https://wa.me/?text=Join my KinCircle: $link');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to generate invite now')),
      );
    }
  }

  Widget _sheetAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: KinCirclePalette.accent),
      title: Text(title, style: KinCircleTypography.body14(weight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, color: KinCirclePalette.textMuted),
    );
  }

  Widget _memberTile(FamilyMember member) {
    final String role = member.isOwner ? 'Admin' : 'Member';
    final Color roleColor = member.isOwner ? KinCirclePalette.accent : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KinCirclePalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KinCirclePalette.border, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: KinCirclePalette.surfaceAlt,
            child: Text(
              _initials(member.displayName),
              style: KinCircleTypography.caption12(color: Colors.white, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              member.displayName,
              style: KinCircleTypography.body14(weight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: KinCircleRadii.pill,
              border: Border.all(color: roleColor, width: 1),
              color: roleColor.withValues(alpha: 0.14),
            ),
            child: Text(
              role,
              style: KinCircleTypography.caption12(color: roleColor, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final List<String> pieces = name
        .trim()
        .split(' ')
        .where((String p) => p.trim().isNotEmpty)
        .toList();
    if (pieces.isEmpty) return 'U';
    if (pieces.length == 1) return pieces.first[0].toUpperCase();
    return '${pieces.first[0]}${pieces.last[0]}'.toUpperCase();
  }

  Widget _body() {
    if (_loading) {
      return ListView.builder(
        itemCount: 6,
        itemBuilder: (_, int index) {
          return Shimmer.fromColors(
            baseColor: KinCirclePalette.surfaceAlt,
            highlightColor: KinCirclePalette.border,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              height: 68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        },
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: KinCirclePalette.error, size: 50),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: KinCircleTypography.body14(color: KinCirclePalette.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: KinCircleButtons.primary(),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_familyId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.family_restroom, color: KinCirclePalette.textMuted, size: 46),
              const SizedBox(height: 10),
              Text(
                'Create a circle first to start inviting members.',
                textAlign: TextAlign.center,
                style: KinCircleTypography.body14(color: KinCirclePalette.textMuted),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                style: KinCircleButtons.primary(),
                onPressed: () => Navigator.of(context).pushNamed('/create-family'),
                child: const Text('Create a Circle'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 8),
        ..._members.map(_memberTile),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ElevatedButton(
            style: KinCircleButtons.primary(),
            onPressed: _openInviteOptions,
            child: const Text('Invite Member'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavShell(
      currentIndex: 1,
      title: 'Invite Family',
      body: _body(),
    );
  }
}
