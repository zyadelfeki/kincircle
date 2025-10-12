import 'package:flutter/material.dart';
import '../../models/emergency_contact.dart';
import '../../services/emergency_response_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final _emergencyService = EmergencyResponseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddContactDialog(),
            tooltip: 'Add Contact',
          ),
        ],
      ),
      body: StreamBuilder<List<EmergencyContact>>(
        stream: _emergencyService.getEmergencyContacts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final contacts = snapshot.data ?? [];

          if (contacts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.contact_emergency, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No emergency contacts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add contacts to notify in case of emergency',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showAddContactDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Contact'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return _buildContactCard(contact);
            },
          );
        },
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(contact.type),
          child: Icon(_getTypeIcon(contact.type), color: Colors.white),
        ),
        title: Text(contact.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact.phoneNumber),
            if (contact.email != null) Text(contact.email!),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                Chip(
                  label: Text(
                    _getTypeLabel(contact.type),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    _getPriorityLabel(contact.priority),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditContactDialog(contact);
            } else if (value == 'delete') {
              _confirmDelete(contact);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog() {
    _showContactDialog(null);
  }

  void _showEditContactDialog(EmergencyContact contact) {
    _showContactDialog(contact);
  }

  void _showContactDialog(EmergencyContact? existingContact) {
    final nameController = TextEditingController(text: existingContact?.name);
    final phoneController = TextEditingController(text: existingContact?.phoneNumber);
    final emailController = TextEditingController(text: existingContact?.email);
    
    EmergencyContactType selectedType = existingContact?.type ?? EmergencyContactType.family;
    EmergencyContactPriority selectedPriority = existingContact?.priority ?? EmergencyContactPriority.secondary;
    bool notifyByPhone = existingContact?.notifyByPhone ?? true;
    bool notifyByEmail = existingContact?.notifyByEmail ?? false;
    bool notifyBySms = existingContact?.notifyBySms ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingContact == null ? 'Add Contact' : 'Edit Contact'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EmergencyContactType>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Contact Type',
                    border: OutlineInputBorder(),
                  ),
                  items: EmergencyContactType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getTypeLabel(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EmergencyContactPriority>(
                  value: selectedPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: EmergencyContactPriority.values.map((priority) {
                    return DropdownMenuItem(
                      value: priority,
                      child: Text(_getPriorityLabel(priority)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedPriority = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text('Notification Methods:', style: TextStyle(fontWeight: FontWeight.bold)),
                CheckboxListTile(
                  title: const Text('Phone Call'),
                  value: notifyByPhone,
                  onChanged: (value) => setDialogState(() => notifyByPhone = value ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('SMS'),
                  value: notifyBySms,
                  onChanged: (value) => setDialogState(() => notifyBySms = value ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Email'),
                  value: notifyByEmail,
                  onChanged: (value) => setDialogState(() => notifyByEmail = value ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and phone are required')),
                  );
                  return;
                }

                try {
                  if (existingContact == null) {
                    // Add new contact
                    await _emergencyService.addEmergencyContact(
                      EmergencyContact(
                        id: '',
                        userId: '',
                        name: nameController.text,
                        phoneNumber: phoneController.text,
                        email: emailController.text.isEmpty ? null : emailController.text,
                        type: selectedType,
                        priority: selectedPriority,
                        notifyByPhone: notifyByPhone,
                        notifyByEmail: notifyByEmail,
                        notifyBySms: notifyBySms,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                  } else {
                    // Update existing contact
                    await _emergencyService.updateEmergencyContact(
                      existingContact.copyWith(
                        name: nameController.text,
                        phoneNumber: phoneController.text,
                        email: emailController.text.isEmpty ? null : emailController.text,
                        type: selectedType,
                        priority: selectedPriority,
                        notifyByPhone: notifyByPhone,
                        notifyByEmail: notifyByEmail,
                        notifyBySms: notifyBySms,
                      ),
                    );
                  }

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existingContact == null 
                          ? 'Contact added successfully' 
                          : 'Contact updated successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: Text(existingContact == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _emergencyService.deleteEmergencyContact(contact.id);
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(EmergencyContactType type) {
    switch (type) {
      case EmergencyContactType.family:
        return Icons.family_restroom;
      case EmergencyContactType.medical:
        return Icons.local_hospital;
      case EmergencyContactType.firstResponder:
        return Icons.emergency;
    }
  }

  Color _getTypeColor(EmergencyContactType type) {
    switch (type) {
      case EmergencyContactType.family:
        return Colors.blue;
      case EmergencyContactType.medical:
        return Colors.green;
      case EmergencyContactType.firstResponder:
        return Colors.red;
    }
  }

  String _getTypeLabel(EmergencyContactType type) {
    switch (type) {
      case EmergencyContactType.family:
        return 'Family';
      case EmergencyContactType.medical:
        return 'Medical';
      case EmergencyContactType.firstResponder:
        return 'First Responder';
    }
  }

  String _getPriorityLabel(EmergencyContactPriority priority) {
    switch (priority) {
      case EmergencyContactPriority.primary:
        return 'Primary';
      case EmergencyContactPriority.secondary:
        return 'Secondary';
      case EmergencyContactPriority.tertiary:
        return 'Tertiary';
    }
  }
}
