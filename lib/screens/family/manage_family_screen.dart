import 'package:flutter/material.dart';
import '../../design/kincircle_screen_tokens.dart';
import '../../models/family.dart';
import '../../services/firestore_service.dart';

class ManageFamilyScreen extends StatefulWidget {
  const ManageFamilyScreen({super.key, this.familyId});

  final String? familyId;

  @override
  State<ManageFamilyScreen> createState() => _ManageFamilyScreenState();
}

class _ManageFamilyScreenState extends State<ManageFamilyScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, dynamic>? _familyDetails;
  Family? _family;
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;
  String? _targetFamilyId;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args =
          (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
      _targetFamilyId = widget.familyId ?? args['familyId'] as String?;
      _loadFamilyDetails();
    }
  }

  Future<void> _loadFamilyDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final familyId = _targetFamilyId ?? await _firestoreService.getCurrentFamilyId();
      if (familyId == null) {
        if (mounted) {
          setState(() {
            _error = 'No family found';
            _isLoading = false;
          });
        }
        return;
      }
      _targetFamilyId = familyId;

      _currentUserId = _firestoreService.getCurrentUid();

      final details = await _firestoreService.getFamilyDetails(familyId);
      final family = await _firestoreService.getFamily(familyId);

      if (mounted) {
        setState(() {
          _familyDetails = details;
          _family = family;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _renameCircle() async {
    final currentName = _familyDetails?['name'] as String? ?? '';
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final palette = KinCirclePalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Rename Circle',
            style: KinCircleTypography.cardTitle16(
              color: palette.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: KinCircleTypography.body14(color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: 'Enter new circle name',
              hintStyle: KinCircleTypography.body14(color: palette.textMuted),
              filled: true,
              fillColor: palette.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.accent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: KinCircleTypography.body14(color: palette.textMuted),
              ),
            ),
            ElevatedButton(
              style: KinCircleButtons.primary(),
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      try {
        final familyId = _targetFamilyId ?? await _firestoreService.getCurrentFamilyId();
        if (familyId != null) {
          await _firestoreService.renameFamily(familyId, newName);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Circle renamed to "$newName"')),
            );
            _loadFamilyDetails();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to rename circle: $e')),
          );
        }
      }
    }
  }

  Future<void> _removeMember(String memberUid, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = KinCirclePalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Remove Member',
            style: KinCircleTypography.cardTitle16(
              color: palette.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to remove $memberName from the circle?',
            style: KinCircleTypography.body14(color: palette.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: KinCircleTypography.body14(color: palette.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Remove',
                style: KinCircleTypography.body14(
                  color: palette.error,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final familyId = _targetFamilyId ?? await _firestoreService.getCurrentFamilyId();
      if (familyId == null) {
        throw Exception('No family found');
      }

      await _firestoreService.removeMember(familyId, memberUid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$memberName has been removed from the circle')),
      );

      _loadFamilyDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove member: $e'),
          backgroundColor: KinCirclePalette.error,
        ),
      );
    }
  }

  Future<void> _leaveFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = KinCirclePalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Leave Circle',
            style: KinCircleTypography.cardTitle16(
              color: palette.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to leave this circle? You will no longer be able to see circle member locations or receive alerts.',
            style: KinCircleTypography.body14(color: palette.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: KinCircleTypography.body14(color: palette.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Leave',
                style: KinCircleTypography.body14(
                  color: palette.error,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final familyId = _targetFamilyId ?? await _firestoreService.getCurrentFamilyId();
      if (familyId == null) {
        throw Exception('No family found');
      }

      await _firestoreService.leaveFamily(familyId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have left the circle')),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave circle: $e'),
          backgroundColor: KinCirclePalette.error,
        ),
      );
    }
  }

  Future<void> _deleteCircle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = KinCirclePalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            'Delete Circle',
            style: KinCircleTypography.cardTitle16(
              color: palette.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this circle? All members will be removed and circle places deleted. This action cannot be undone.',
            style: KinCircleTypography.body14(color: palette.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: KinCircleTypography.body14(color: palette.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Delete',
                style: KinCircleTypography.body14(
                  color: palette.error,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final familyId = _targetFamilyId ?? await _firestoreService.getCurrentFamilyId();
      if (familyId == null) {
        throw Exception('No family found');
      }

      await _firestoreService.deleteFamily(familyId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Circle deleted successfully')),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete circle: $e'),
          backgroundColor: KinCirclePalette.error,
        ),
      );
    }
  }

  bool _isCurrentUserOwner() {
    if (_family == null || _currentUserId == null) return false;
    return _family!.isOwner(_currentUserId!);
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text(
          'Manage Circle',
          style: KinCircleTypography.cardTitle16(
            color: palette.textPrimary,
            weight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_familyDetails != null)
            IconButton(
              icon: Icon(Icons.person_add_outlined, color: palette.textPrimary),
              tooltip: 'Invite Member',
              onPressed: () => Navigator.of(context).pushNamed('/invite'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(palette)
              : _familyDetails == null
                  ? _buildNoFamilyState(palette)
                  : _buildFamilyContent(palette),
    );
  }

  Widget _buildErrorState(KinCirclePaletteData palette) {
    final isNoFamily = _error == 'No family found';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNoFamily ? Icons.groups_2_outlined : Icons.error_outline,
              size: 72,
              color: isNoFamily ? palette.accent : palette.error,
            ),
            const SizedBox(height: 20),
            Text(
              isNoFamily ? 'No Circle Yet' : 'Something went wrong',
              style: KinCircleTypography.heading22(
                color: palette.textPrimary,
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isNoFamily
                  ? 'Create a circle to start connecting and protecting your loved ones.'
                  : _error!,
              style: KinCircleTypography.body14(color: palette.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isNoFamily) ...[
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/create-family'),
                icon: const Icon(Icons.add),
                label: const Text('Create Circle'),
                style: KinCircleButtons.primary(),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/manage-invites'),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Check Pending Invites'),
                style: KinCircleButtons.secondary(),
              ),
            ] else
              ElevatedButton.icon(
                onPressed: _loadFamilyDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: KinCircleButtons.primary(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFamilyState(KinCirclePaletteData palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_2_outlined, size: 72, color: palette.accent),
            const SizedBox(height: 20),
            Text(
              'Start Your Circle',
              style: KinCircleTypography.heading22(
                color: palette.textPrimary,
                weight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Create a circle to keep your loved ones safe and connected.',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(color: palette.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/create-family'),
              icon: const Icon(Icons.add),
              label: const Text('Create Circle'),
              style: KinCircleButtons.primary(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyContent(KinCirclePaletteData palette) {
    final familyName = _familyDetails!['name'] as String? ?? 'Circle';
    final members = (_familyDetails!['members'] as List<dynamic>?) ?? [];
    final isOwner = _isCurrentUserOwner();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: palette.accent.withValues(alpha: 0.2),
                  child: Icon(Icons.groups_2, color: palette.accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        familyName,
                        style: KinCircleTypography.heading22(
                          color: palette.textPrimary,
                          weight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${members.length} member${members.length != 1 ? 's' : ''}',
                        style: KinCircleTypography.body14(color: palette.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: palette.textMuted),
                  tooltip: 'Rename Circle',
                  onPressed: _renameCircle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Circle Members',
            style: KinCircleTypography.cardTitle16(
              color: palette.textPrimary,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: members.length,
              separatorBuilder: (_, __) => Divider(height: 8, color: palette.border),
              itemBuilder: (context, index) {
                final member = members[index] as Map<String, dynamic>;
                final memberUid = member['uid'] as String? ?? '';
                final memberName = member['displayName'] as String? ?? 'Member';
                final memberEmail = member['email'] as String? ?? '';
                final memberIsOwner = member['isOwner'] as bool? ?? false;
                final isCurrentUser = memberUid == _currentUserId;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: memberIsOwner
                        ? palette.accent.withValues(alpha: 0.2)
                        : palette.surfaceAlt,
                    child: Text(
                      memberName.isNotEmpty ? memberName[0].toUpperCase() : 'U',
                      style: KinCircleTypography.body14(
                        color: memberIsOwner ? palette.accent : palette.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          memberName,
                          style: KinCircleTypography.body14(
                            color: palette.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (memberIsOwner)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Owner',
                            style: KinCircleTypography.caption12(
                              color: palette.accent,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (isCurrentUser)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'You',
                            style: KinCircleTypography.caption12(
                              color: palette.textMuted,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: memberEmail.isNotEmpty
                      ? Text(
                          memberEmail,
                          style: KinCircleTypography.caption12(color: palette.textMuted),
                        )
                      : null,
                  trailing: isOwner && !isCurrentUser
                      ? IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: palette.error),
                          onPressed: () => _removeMember(memberUid, memberName),
                          tooltip: 'Remove member',
                        )
                      : null,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (isOwner)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _deleteCircle,
                icon: Icon(Icons.delete_outline, color: palette.error),
                label: Text(
                  'Delete Circle',
                  style: KinCircleTypography.body14(
                    color: palette.error,
                    weight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _leaveFamily,
                icon: Icon(Icons.exit_to_app, color: palette.error),
                label: Text(
                  'Leave Circle',
                  style: KinCircleTypography.body14(
                    color: palette.error,
                    weight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
