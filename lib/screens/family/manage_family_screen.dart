import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/family.dart';

class ManageFamilyScreen extends StatefulWidget {
  const ManageFamilyScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadFamilyDetails();
  }

  Future<void> _loadFamilyDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final familyId = await _firestoreService.getCurrentFamilyId();
      if (familyId == null) {
        setState(() {
          _error = 'No family found';
          _isLoading = false;
        });
        return;
      }

      // Get current user ID
      _currentUserId = _firestoreService.getCurrentUid();

      // Get both the detailed family info and the Family model
      final details = await _firestoreService.getFamilyDetails(familyId);
      final family = await _firestoreService.getFamily(familyId);
      
      setState(() {
        _familyDetails = details;
        _family = family;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeMember(String memberUid, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $memberName from the family?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final familyId = await _firestoreService.getCurrentFamilyId();
      if (familyId == null) {
        throw Exception('No family found');
      }

      await _firestoreService.removeMember(familyId, memberUid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$memberName has been removed from the family')),
      );

      // Reload the family details
      _loadFamilyDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove member: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _leaveFamily() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Family'),
        content: const Text(
          'Are you sure you want to leave this family? You will no longer be able to see family member locations or receive alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final familyId = await _firestoreService.getCurrentFamilyId();
      if (familyId == null) {
        throw Exception('No family found');
      }

      await _firestoreService.leaveFamily(familyId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have left the family')),
      );

      // Navigate back to the main screen or dashboard
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to leave family: $e'),
          backgroundColor: Colors.red,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Family'),
        actions: [
          if (_familyDetails != null)
            IconButton(
              icon: const Icon(Icons.person_add),
              tooltip: 'Invite Member',
              onPressed: () => Navigator.of(context).pushNamed('/invite'),
            ),
        ],
      ),
      floatingActionButton: _familyDetails != null
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).pushNamed('/invite'),
              icon: const Icon(Icons.person_add),
              label: const Text('Invite'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _familyDetails == null
                  ? _buildNoFamilyState()
                  : _buildFamilyContent(),
    );
  }

  Widget _buildErrorState() {
    final isNoFamily = _error == 'No family found';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isNoFamily ? Icons.family_restroom : Icons.error_outline,
              size: 80,
              color: isNoFamily ? Colors.blue : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              isNoFamily ? 'No Family Yet' : 'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isNoFamily 
                  ? 'Create a family to start tracking and protecting your loved ones.'
                  : _error!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (isNoFamily) ...[
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/create-family'),
                icon: const Icon(Icons.add),
                label: const Text('Create Family'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 56),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/manage-invites'),
                icon: const Icon(Icons.mail),
                label: const Text('Check Pending Invites'),
              ),
            ] else
              ElevatedButton.icon(
                onPressed: _loadFamilyDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFamilyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.family_restroom, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              'Start Your Family Circle',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a family to keep your loved ones safe and connected.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/create-family'),
              icon: const Icon(Icons.add),
              label: const Text('Create Family'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyContent() {
    final familyName = _familyDetails!['name'] as String;
    final members = _familyDetails!['members'] as List<dynamic>;
    final isOwner = _isCurrentUserOwner();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Family name header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    Icons.family_restroom,
                    size: 32,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          familyName,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          '${members.length} member${members.length != 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Members section
          Text(
            'Family Members',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          // Members list
          Expanded(
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final memberUid = member['uid'] as String;
                final memberName = member['displayName'] as String;
                final memberEmail = member['email'] as String;
                final memberIsOwner = member['isOwner'] as bool;
                final isCurrentUser = memberUid == _currentUserId;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: memberIsOwner
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300],
                      child: Icon(
                        memberIsOwner ? Icons.star : Icons.person,
                        color: memberIsOwner ? Colors.white : Colors.grey[600],
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(memberName)),
                        if (memberIsOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Owner',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (isCurrentUser)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(memberEmail),
                    trailing: isOwner && !isCurrentUser
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red,
                            onPressed: () => _removeMember(memberUid, memberName),
                            tooltip: 'Remove member',
                          )
                        : null,
                  ),
                );
              },
            ),
          ),

          // Leave family button (only for non-owners)
          if (!isOwner) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _leaveFamily,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Leave Family',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
