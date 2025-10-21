import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/emergency_contact.dart';

/// Emergency Contacts Management Screen
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    try {
      // For demo purposes, use demo contacts
      // In production, load from Firestore using EmergencyResponseService.getEmergencyContacts()
      _contacts = _getDemoContacts();
    } catch (e) {
      print('Error loading contacts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<EmergencyContact> _getDemoContacts() {
    return [
      EmergencyContact(
        id: '1',
        name: 'Sarah Johnson',
        phoneNumber: '+1-555-0101',
        email: 'sarah.johnson@email.com',
        type: EmergencyContactType.primaryFamily,
        priority: 1,
        preferredContactMethods: ['call', 'sms'],
        specialInstructions: 'Daughter - Available 24/7',
        medicalInfo: 'Power of attorney, knows all medications',
      ),
      EmergencyContact(
        id: '2',
        name: 'Mike Johnson',
        phoneNumber: '+1-555-0102',
        type: EmergencyContactType.primaryFamily,
        priority: 2,
        preferredContactMethods: ['call'],
        specialInstructions: 'Son - Lives nearby, can respond quickly',
      ),
      EmergencyContact(
        id: '3',
        name: 'Maria Rodriguez',
        phoneNumber: '+1-555-0201',
        type: EmergencyContactType.caregiver,
        priority: 3,
        preferredContactMethods: ['call', 'sms'],
        specialInstructions: 'Professional caregiver - Available Mon-Fri 8am-6pm',
      ),
      EmergencyContact(
        id: '4',
        name: 'Dr. Smith',
        phoneNumber: '+1-555-0301',
        email: 'dr.smith@clinic.com',
        type: EmergencyContactType.medicalProfessional,
        priority: 4,
        preferredContactMethods: ['sms', 'email'],
        medicalInfo: 'Primary care physician - Alzheimer medication manager, emergency medical history',
      ),
      EmergencyContact(
        id: '5',
        name: 'Betty Wilson',
        phoneNumber: '+1-555-0401',
        type: EmergencyContactType.neighbor,
        priority: 5,
        preferredContactMethods: ['call'],
        specialInstructions: 'Trusted neighbor - Next door, has spare keys',
      ),
      EmergencyContact(
        id: '911',
        name: 'Emergency Services',
        phoneNumber: '911',
        type: EmergencyContactType.emergency911,
        priority: 99,
        preferredContactMethods: ['call'],
        specialInstructions: 'For critical emergencies only',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚨 Emergency Contacts'),
        backgroundColor: Colors.red.shade700,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                return _buildContactCard(_contacts[index]);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add contact feature coming soon')),
          );
        },
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon, name, and priority
            Row(
              children: [
                _buildContactTypeIcon(contact.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Priority ${contact.priority}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Contact info
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(contact.phoneNumber),
              ],
            ),
            if (contact.email != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(contact.email!),
                ],
              ),
            ],
            const SizedBox(height: 12),

            // Preferred contact methods
            Wrap(
              spacing: 8,
              children: contact.preferredContactMethods.map((method) {
                return Chip(
                  label: Text(method.toUpperCase()),
                  backgroundColor: Colors.blue.shade100,
                  labelStyle: const TextStyle(fontSize: 11),
                );
              }).toList(),
            ),

            // Special instructions
            if (contact.specialInstructions != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contact.specialInstructions!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Medical info
            if (contact.medicalInfo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.medical_information,
                        size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        contact.medicalInfo!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _testCall(contact),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Test Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editContact(contact),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTypeIcon(EmergencyContactType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case EmergencyContactType.primaryFamily:
        iconData = Icons.family_restroom;
        color = Colors.blue.shade700;
        break;
      case EmergencyContactType.secondaryFamily:
        iconData = Icons.people;
        color = Colors.blue.shade400;
        break;
      case EmergencyContactType.caregiver:
        iconData = Icons.health_and_safety;
        color = Colors.purple.shade700;
        break;
      case EmergencyContactType.medicalProfessional:
        iconData = Icons.medical_services;
        color = Colors.red.shade700;
        break;
      case EmergencyContactType.neighbor:
        iconData = Icons.home;
        color = Colors.green.shade700;
        break;
      case EmergencyContactType.emergency911:
        iconData = Icons.emergency;
        color = Colors.red.shade900;
        break;
      case EmergencyContactType.friend:
        iconData = Icons.person;
        color = Colors.teal.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  Future<void> _testCall(EmergencyContact contact) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Call'),
        content: Text('Call ${contact.name} at ${contact.phoneNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Call'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: contact.phoneNumber);
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
        await HapticFeedback.heavyImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Calling ${contact.name}...')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _editContact(EmergencyContact contact) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit contact feature coming soon')),
    );
  }
}
