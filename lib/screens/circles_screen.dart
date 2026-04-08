import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../design/kincircle_screen_tokens.dart';
import '../widgets/dashboard/dashboard_card_shimmer.dart';
import '../widgets/nav_shell.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _circlesStream;

  @override
  void initState() {
    super.initState();
    _circlesStream = _buildCirclesStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildCirclesStream() {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    return _firestore
        .collection('families')
        .where('members', arrayContains: uid)
        .snapshots();
  }

  void _retry() {
    setState(() {
      _circlesStream = _buildCirclesStream();
    });
  }

  void _openCreateCircle() {
    Navigator.of(context).pushNamed('/create-family');
  }

  void _openJoinCircle() {
    Navigator.of(context).pushNamed('/join-family');
  }

  @override
  Widget build(BuildContext context) {
    return NavShell(
      currentIndex: 2,
      title: 'Circles',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _circlesStream,
        builder: (BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
              title: 'Unable to load circles',
              message: 'Check your connection or permissions.',
              onRetry: _retry,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _CirclesLoadingState();
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> circles =
              snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (circles.isEmpty) {
            return _CirclesEmptyState(
              onCreateCircle: _openCreateCircle,
              onJoinCircle: _openJoinCircle,
            );
          }

          return _CirclesListState(
            circles: circles,
            onCreateCircle: _openCreateCircle,
            onJoinCircle: _openJoinCircle,
          );
        },
      ),
    );
  }
}

class _CirclesLoadingState extends StatelessWidget {
  const _CirclesLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: const [
        DashboardCardShimmer(height: 132),
        SizedBox(height: 12),
        DashboardCardShimmer(height: 132),
        SizedBox(height: 12),
        DashboardCardShimmer(height: 132),
      ],
    );
  }
}

class _CirclesListState extends StatelessWidget {
  const _CirclesListState({
    required this.circles,
    required this.onCreateCircle,
    required this.onJoinCircle,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> circles;
  final VoidCallback onCreateCircle;
  final VoidCallback onJoinCircle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            itemCount: circles.length,
            itemBuilder: (BuildContext context, int index) {
              return _CircleCard(circleDoc: circles[index]);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
          ),
        ),
        _BottomActions(
          onCreateCircle: onCreateCircle,
          onJoinCircle: onJoinCircle,
        ),
      ],
    );
  }
}

class _CirclesEmptyState extends StatelessWidget {
  const _CirclesEmptyState({
    required this.onCreateCircle,
    required this.onJoinCircle,
  });

  final VoidCallback onCreateCircle;
  final VoidCallback onJoinCircle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.group_add_outlined,
              color: KinCirclePalette.textMuted,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              'No circles yet',
              style: KinCircleTypography.cardTitle16(weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or join a circle to get started.',
              textAlign: TextAlign.center,
              style:
                  KinCircleTypography.body14(color: KinCirclePalette.textMuted),
            ),
            const SizedBox(height: 20),
            _BottomActions(
              onCreateCircle: onCreateCircle,
              onJoinCircle: onJoinCircle,
              addOuterPadding: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleCard extends StatelessWidget {
  const _CircleCard({
    required this.circleDoc,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> circleDoc;

  List<String> _memberIds(Map<String, dynamic> data) {
    final dynamic rawMembers = data['members'];
    if (rawMembers is! List) {
      return <String>[];
    }
    return rawMembers
        .map((dynamic member) => member.toString())
        .where((String uid) => uid.isNotEmpty)
        .toList();
  }

  String _initialFromMember(String memberId) {
    if (memberId.isEmpty) return '?';
    return memberId.substring(0, 1).toUpperCase();
  }

  Color _avatarColor(int index) {
    final List<Color> swatches = <Color>[
      KinCirclePalette.accent.withValues(alpha: 0.24),
      KinCirclePalette.surfaceAlt,
      KinCirclePalette.border,
      KinCirclePalette.accent.withValues(alpha: 0.36),
    ];
    return swatches[index % swatches.length];
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data = circleDoc.data();
    final String name = (data['name'] as String?)?.trim().isNotEmpty == true
        ? (data['name'] as String).trim()
        : 'Circle';
    final List<String> members = _memberIds(data);
    final int memberCount = members.length;
    final List<String> visibleMembers = members.take(4).toList();

    return Material(
      color: KinCirclePalette.background.withValues(alpha: 0),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(
          '/circle-detail',
          arguments: <String, String>{'familyId': circleDoc.id},
        ),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: KinCirclePalette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: KinCirclePalette.border,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: KinCircleTypography.cardTitle16(
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                      style: KinCircleTypography.body14(
                        color: KinCirclePalette.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: visibleMembers
                          .asMap()
                          .entries
                          .map(
                            (MapEntry<int, String> entry) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: _avatarColor(entry.key),
                                child: Text(
                                  _initialFromMember(entry.value),
                                  style: KinCircleTypography.caption12(
                                    color: KinCirclePalette.textPrimary,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Manage',
                    style: KinCircleTypography.body14(
                      color: KinCirclePalette.textMuted,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: KinCirclePalette.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.onCreateCircle,
    required this.onJoinCircle,
    this.addOuterPadding = true,
  });

  final VoidCallback onCreateCircle;
  final VoidCallback onJoinCircle;
  final bool addOuterPadding;

  @override
  Widget build(BuildContext context) {
    final Widget actions = Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onCreateCircle,
            style: KinCircleButtons.primary(),
            child: const Text('Create Circle'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: onJoinCircle,
            style: KinCircleButtons.secondary(),
            child: const Text('Join Circle'),
          ),
        ),
      ],
    );

    if (!addOuterPadding) {
      return actions;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: actions,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: KinCirclePalette.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: KinCirclePalette.border),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: KinCirclePalette.accent,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: KinCircleTypography.cardTitle16(weight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(
                color: KinCirclePalette.textMuted,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: KinCircleButtons.primary(),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
