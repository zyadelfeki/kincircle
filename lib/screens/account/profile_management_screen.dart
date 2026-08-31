import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../design/kincircle_screen_tokens.dart';

class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  State<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();

  bool _saving = false;
  bool _loading = true;
  String? _photoUrl;
  String _selectedRole = 'family_member';

  final List<String> _roles = [
    'family_member',
    'caregiver',
    'care_recipient',
    'parent',
    'child',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    _displayNameCtrl.text = u.displayName ?? '';
    _photoUrl = u.photoURL;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        _phoneCtrl.text = data['phone'] ?? '';
        _emergencyContactCtrl.text = data['emergencyContactName'] ?? '';
        _emergencyPhoneCtrl.text = data['emergencyContactPhone'] ?? '';
        _selectedRole = data['role'] ?? 'family_member';
      }
    } catch (_) {
      // Profile data may not exist yet
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyContactCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        // Update Firebase Auth profile
        await u.updateDisplayName(_displayNameCtrl.text.trim());

        // Update extended profile in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(u.uid)
            .set({
          'displayName': _displayNameCtrl.text.trim(),
          'email': u.email,
          'phone': _phoneCtrl.text.trim(),
          'emergencyContactName': _emergencyContactCtrl.text.trim(),
          'emergencyContactPhone': _emergencyPhoneCtrl.text.trim(),
          'role': _selectedRole,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (mounted) {
          final palette = KinCirclePalette.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile updated successfully'),
              backgroundColor: palette.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final palette = KinCirclePalette.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: palette.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'caregiver':
        return 'Caregiver';
      case 'care_recipient':
        return 'Care Recipient';
      case 'parent':
        return 'Parent';
      case 'child':
        return 'Child';
      default:
        return 'Family Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: KinCircleTypography.cardTitle16(
            color: palette.textPrimary,
            weight: FontWeight.w700,
          ),
        ),
        backgroundColor: palette.surface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.accent,
                      ),
                    )
                  : Text(
                      'Save',
                      style: KinCircleTypography.body14(
                        color: palette.accent,
                        weight: FontWeight.w700,
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: palette.accent,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Picture Section
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: palette.accent.withValues(alpha: 0.2),
                            backgroundImage: _photoUrl != null
                                ? NetworkImage(_photoUrl!)
                                : null,
                            child: _photoUrl == null
                                ? Text(
                                    (_displayNameCtrl.text.isNotEmpty
                                        ? _displayNameCtrl.text[0].toUpperCase()
                                        : user?.email?[0].toUpperCase() ?? 'U'),
                                    style: KinCircleTypography.heading22(
                                      color: palette.accent,
                                      weight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: palette.accent,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 16),
                                color: Colors.white,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Photo upload coming in next update'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        user?.email ?? '',
                        style: KinCircleTypography.caption12(
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Basic Info Section
                    _buildSectionHeader('Basic Information', palette),
                    const SizedBox(height: 12),
                    Container(
                      decoration: KinCircleDecorations.input(palette),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextFormField(
                        controller: _displayNameCtrl,
                        style: KinCircleTypography.body14(
                          color: palette.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          labelStyle: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: palette.textSecondary,
                          ),
                          border: InputBorder.none,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: KinCircleDecorations.input(palette),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextFormField(
                        controller: _phoneCtrl,
                        style: KinCircleTypography.body14(
                          color: palette.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.phone_outlined,
                            color: palette.textSecondary,
                          ),
                          hintText: '+1 (555) 123-4567',
                          hintStyle: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                          border: InputBorder.none,
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: KinCircleDecorations.input(palette),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedRole,
                        dropdownColor: palette.surface,
                        style: KinCircleTypography.body14(
                          color: palette.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'My Role in Family',
                          labelStyle: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.badge_outlined,
                            color: palette.textSecondary,
                          ),
                          border: InputBorder.none,
                        ),
                        items: _roles.map((role) {
                          return DropdownMenuItem(
                            value: role,
                            child: Text(
                              _getRoleLabel(role),
                              style: KinCircleTypography.body14(
                                color: palette.textPrimary,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedRole = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Emergency Contact Section
                    _buildSectionHeader('Emergency Contact', palette),
                    const SizedBox(height: 4),
                    Text(
                      'This person will be contacted in case of emergency.',
                      style: KinCircleTypography.caption12(
                        color: palette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: KinCircleDecorations.input(palette),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextFormField(
                        controller: _emergencyContactCtrl,
                        style: KinCircleTypography.body14(
                          color: palette.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Contact Name',
                          labelStyle: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.contact_emergency_outlined,
                            color: palette.textSecondary,
                          ),
                          border: InputBorder.none,
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: KinCircleDecorations.input(palette),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextFormField(
                        controller: _emergencyPhoneCtrl,
                        style: KinCircleTypography.body14(
                          color: palette.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Contact Phone',
                          labelStyle: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                          prefixIcon: Icon(
                            Icons.phone_callback_outlined,
                            color: palette.textSecondary,
                          ),
                          hintText: '+1 (555) 123-4567',
                          hintStyle: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                          border: InputBorder.none,
                        ),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Privacy & Data Management link
                    _buildSectionHeader('Privacy & Data', palette),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border, width: 1),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.security_outlined,
                          color: palette.accent,
                        ),
                        title: Text(
                          'Privacy Dashboard & Data Export',
                          style: KinCircleTypography.body14(
                            color: palette.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Manage consents, export data, or delete history',
                          style: KinCircleTypography.caption12(
                            color: palette.textMuted,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: palette.textMuted,
                        ),
                        onTap: () => Navigator.of(context)
                            .pushNamed('/privacy/dashboard'),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: KinCircleButtons.primary(),
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _saving ? 'Saving...' : 'Save All Changes',
                          style: KinCircleTypography.body14(
                            color: Colors.white,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, KinCirclePaletteData palette) {
    return Text(
      title,
      style: KinCircleTypography.cardTitle16(
        color: palette.textPrimary,
        weight: FontWeight.w700,
      ),
    );
  }
}
