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

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadCircleDetail();
    }
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
    final palette = KinCirclePalette.of(context);
    final args = (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
    final String? circleId = args['familyId'] as String? ?? _circleId;
    
    if (circleId == null) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: Text(
            'Circle not found',
            style: KinCircleTypography.body14(color: palette.textMuted),
          ),
        ),
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
                          Icon(Icons.error_outline, color: palette.error, size: 50),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load circle details',
                            style: KinCircleTypography.cardTitle16(
                              color: palette.textPrimary,
                              weight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please check your connection and try again.',
                            style: KinCircleTypography.body14(color: palette.textMuted),
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
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: palette.accent.withValues(alpha: 0.2),
                                child: Text(
                                  _circleName?.isNotEmpty == true 
                                      ? _circleName![0].toUpperCase() 
                                      : 'C',
                                  style: KinCircleTypography.cardTitle16(
                                    color: palette.accent,
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
                                      style: KinCircleTypography.heading22(
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${members.length} ${members.length == 1 ? 'member' : 'members'}',
                                      style: KinCircleTypography.body14(
                                        color: palette.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: palette.textMuted),
                                onPressed: _manageCircle,
                                tooltip: 'Manage Circle',
                              ),
                            ],
                          ),
                          Divider(height: 24, color: palette.border),
                        ],
                      ),
                    ),
                    if (members.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
                        child: Text(
                          'Members',
                          style: KinCircleTypography.cardTitle16(
                            color: palette.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        separatorBuilder: (_, __) => Divider(height: 12, color: palette.border),
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
                                  ? palette.accent.withValues(alpha: 0.2) 
                                  : palette.surfaceAlt,
                              child: Text(
                                displayName.isNotEmpty 
                                    ? displayName[0].toUpperCase() 
                                    : 'U',
                                style: KinCircleTypography.body14(
                                  color: isOwner 
                                      ? palette.accent 
                                      : palette.textPrimary,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: KinCircleTypography.body14(
                                color: palette.textPrimary,
                                weight: FontWeight.w600,
                              ),
                            ),
                            subtitle: email.isNotEmpty
                                ? Text(
                                    email,
                                    style: KinCircleTypography.caption12(
                                      color: palette.textMuted,
                                    ),
                                  )
                                : null,
                            trailing: isOwner
                                ? Icon(
                                    Icons.shield,
                                    color: palette.accent,
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
                              color: palette.textMuted,
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