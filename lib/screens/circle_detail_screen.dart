import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../widgets/nav_shell.dart';

class CircleDetailScreen extends StatefulWidget {
  const CircleDetailScreen({super.key});

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  late Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream;
  bool _isLoading = true;
  String? _circleName;
  String? _circleId;

  @override
  void initState() {
    super.initState();
    _loadCircleDetail();
  }

  void _loadCircleDetail() {
    final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
    final String? circleId = args['familyId'] as String?;
    
    if (circleId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    _circleId = circleId;
    
    _firestore.collection('families').doc(circleId).get().then((doc) {
      if (doc.exists && mounted) {
        setState(() {
          _circleName = doc.data()?['name'] as String?;
        });
      }
    }).catchError((e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });

    _membersStream = _firestore
        .collection('families')
        .doc(circleId)
        .collection('members')
        .snapshots();
        
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _manageCircle() {
    if (_circleId != null) {
      Navigator.of(context).pushNamed(
        '/manage-family',
        arguments: {'familyId': _circleId},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
    final String? circleId = args['familyId'] as String?;
    
    if (circleId == null) {
      return const Scaffold(
        body: Center(child: Text('Circle not found')),
      );
    }

    return NavShell(
      currentIndex: 1,
      title: _circleName ?? 'Circle Details',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _membersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: KinCirclePalette.error, size: 50),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load circle details',
                            style: KinCircleTypography.cardTitle16(weight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please check your connection and try again.',
                            style: KinCircleTypography.body14(color: KinCirclePalette.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loadCircleDetail,
                            style: KinCircleButtons.primary(),
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final members = snapshot.data?.docs ?? [];
                
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: KinCirclePalette.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: KinCirclePalette.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: KinCirclePalette.accent.withValues(alpha: 0.2),
                                child: Text(
                                  _circleName?.isNotEmpty == true 
                                      ? _circleName![0].toUpperCase() 
                                      : 'C',
                                  style: KinCircleTypography.cardTitle16(
                                    color: KinCirclePalette.accent,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _circleName ?? 'Circle',
                                      style: KinCircleTypography.heading22(),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${members.length} ${members.length == 1 ? 'member' : 'members'}',
                                      style: KinCircleTypography.body14(
                                        color: KinCirclePalette.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: _manageCircle,
                                tooltip: 'Manage Circle',
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                        ],
                      ),
                    ),
                    if (members.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Members',
                          style: KinCircleTypography.cardTitle16(weight: FontWeight.w600),
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (_, __) => const Divider(height: 12),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final memberData = members[index].data();
                          final String displayName = memberData['displayName'] ?? 'Unknown';
                          final String email = memberData['email'] ?? '';
                          final bool isOwner = memberData['isOwner'] ?? false;
                          
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: isOwner 
                                  ? KinCirclePalette.accent.withValues(alpha: 0.2) 
                                  : KinCirclePalette.surfaceAlt,
                              child: Text(
                                displayName.isNotEmpty 
                                    ? displayName[0].toUpperCase() 
                                    : 'U',
                                style: KinCircleTypography.body14(
                                  color: isOwner 
                                      ? KinCirclePalette.accent 
                                      : KinCirclePalette.textPrimary,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: KinCircleTypography.body14(
                                weight: FontWeight.w600,
                              ),
                            ),
                            subtitle: email.isNotEmpty
                                ? Text(
                                    email,
                                    style: KinCircleTypography.caption12(
                                      color: KinCirclePalette.textMuted,
                                    ),
                                  )
                                : null,
                            trailing: isOwner
                                ? const Icon(
                                    Icons.shield,
                                    color: KinCirclePalette.accent,
                                    size: 20,
                                  )
                                : null,
                          );
                        },
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No members yet',
                            style: KinCircleTypography.body14(
                              color: KinCirclePalette.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}