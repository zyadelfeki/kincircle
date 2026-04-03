import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = true;

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
      setState(() => _loading = false);
      return;
    }
    
    _displayNameCtrl.text = u.displayName ?? '';
    _photoUrl = u.photoURL;
    
    // Load extended profile from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(u.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        _phoneCtrl.text = data['phone'] ?? '';
        _emergencyContactCtrl.text = data['emergencyContactName'] ?? '';
        _emergencyPhoneCtrl.text = data['emergencyContactPhone'] ?? '';
        _selectedRole = data['role'] ?? 'family_member';
        _notificationsEnabled = data['notificationsEnabled'] ?? true;
        _locationSharingEnabled = data['locationSharingEnabled'] ?? true;
      }
    } catch (e) {
      // Profile data may not exist yet, that's okay
    }
    
    setState(() => _loading = false);
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
          'notificationsEnabled': _notificationsEnabled,
          'locationSharingEnabled': _locationSharingEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'caregiver': return 'Caregiver';
      case 'care_recipient': return 'Care Recipient';
      case 'parent': return 'Parent';
      case 'child': return 'Child';
      default: return 'Family Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account & Profile'),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saving ? null : _save,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                            radius: 60,
                            backgroundColor: Colors.blue.shade100,
                            backgroundImage: _photoUrl != null 
                                ? NetworkImage(_photoUrl!) 
                                : null,
                            child: _photoUrl == null
                                ? Text(
                                    (_displayNameCtrl.text.isNotEmpty
                                        ? _displayNameCtrl.text[0].toUpperCase()
                                        : user?.email?[0].toUpperCase() ?? 'U'),
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Theme.of(context).primaryColor,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18),
                                color: Colors.white,
                                onPressed: () {
                                  // TODO: Implement photo picker
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Photo upload coming in next update'),
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
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Basic Info Section
                    _buildSectionHeader('Basic Information'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _displayNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        hintText: '+1 (555) 123-4567',
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'My Role in Family',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      items: _roles.map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(_getRoleLabel(role)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Emergency Contact Section
                    _buildSectionHeader('Emergency Contact'),
                    const SizedBox(height: 8),
                    Text(
                      'This person will be contacted in case of emergency',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emergencyContactCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Name',
                        prefixIcon: Icon(Icons.contact_emergency),
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emergencyPhoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone',
                        prefixIcon: Icon(Icons.phone_callback),
                        border: OutlineInputBorder(),
                        hintText: '+1 (555) 123-4567',
                      ),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),
                    
                    // Preferences Section
                    _buildSectionHeader('Preferences'),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Push Notifications'),
                            subtitle: const Text('Receive alerts about family activity'),
                            value: _notificationsEnabled,
                            onChanged: (value) {
                              setState(() => _notificationsEnabled = value);
                            },
                            secondary: const Icon(Icons.notifications),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Location Sharing'),
                            subtitle: const Text('Share your location with family'),
                            value: _locationSharingEnabled,
                            onChanged: (value) {
                              setState(() => _locationSharingEnabled = value);
                            },
                            secondary: const Icon(Icons.location_on),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Account Actions Section
                    _buildSectionHeader('Account'),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.password),
                            title: const Text('Change Password'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showChangePasswordDialog(),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.download),
                            title: const Text('Export My Data'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Data export request submitted. You\'ll receive an email within 24 hours.'),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(Icons.delete_forever, color: Colors.red.shade400),
                            title: Text(
                              'Delete Account',
                              style: TextStyle(color: Colors.red.shade400),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showDeleteAccountDialog(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save All Changes'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  void _showChangePasswordDialog() {
    final emailController = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.email ?? '',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'We\'ll send a password reset link to your email address.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: emailController.text,
                );
                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Password reset email sent!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Delete Account'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete your account? This action cannot be undone.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            Text('• All your data will be permanently deleted'),
            Text('• You\'ll be removed from all family circles'),
            Text('• Your location history will be erased'),
            Text('• You won\'t be able to recover your account'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);
              // Show confirmation with password
              _confirmAccountDeletion();
            },
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _confirmAccountDeletion() {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your password to confirm account deletion:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && user.email != null) {
                  // Re-authenticate
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passwordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  
                  // Delete Firestore data
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .delete();
                  
                  // Delete auth account
                  await user.delete();

                  if (!mounted) return;
                  nav.popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Confirm Delete'),
          ),
        ],
      ),
    );
  }
}
