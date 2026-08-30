import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../design/kincircle_screen_tokens.dart';
import '../widgets/circles/family_leaderboard.dart';
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

  void _openSupport() {
    Navigator.of(context).pushNamed('/support/remote');
  }

  @override
  Widget build(BuildContext context) {
    return NavShell(
      currentIndex: 1,
      title: 'Circles',
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _circlesStream,
        builder: (BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.hasError) {
            final Object? error = snapshot.error;
            final bool permissionDenied = error is FirebaseException &&
                error.code == 'permission-denied';
            return _ErrorState(
              title: 'Can\'t load your circles',
              message: permissionDenied
                  ? 'There\'s a setup issue. Contact support.'
                  : 'Check your connection and try again.',
              onRetry: permissionDenied ? _openSupport : _retry,
              actionLabel: permissionDenied ? 'Contact Support' : 'Try Again',
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
      padding: const EdgeInsets.all(16),
      children: const [
        DashboardCardShimmer(height: 128),
        SizedBox(height: 8),
        DashboardCardShimmer(height: 128),
        SizedBox(height: 8),
        DashboardCardShimmer(height: 128),
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
    final String activeFamilyId = circles.first.id;
    final String? circleName = circles.first.data()['name'] as String?;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              FamilyLeaderboardWidget(
                familyId: activeFamilyId,
                circleName: circleName,
              ),
              ...circles.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CircleCard(circleDoc: doc),
                  )),
            ],
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
    final palette = KinCirclePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_add_outlined,
              color: palette.textMuted,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No circles yet',
              style: KinCircleTypography.cardTitle16(
                color: palette.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create or join a circle to get started.',
              textAlign: TextAlign.center,
              style:
                  KinCircleTypography.body14(color: palette.textMuted),
            ),
            const SizedBox(height: 24),
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

  Color _avatarColor(int index, KinCirclePaletteData palette) {
    final List<Color> swatches = <Color>[
      palette.accent.withValues(alpha: 0.24),
      palette.surfaceAlt,
      palette.border,
      palette.accent.withValues(alpha: 0.36),
    ];
    return swatches[index % swatches.length];
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    final Map<String, dynamic> data = circleDoc.data();
    final String name = (data['name'] as String?)?.trim().isNotEmpty == true
        ? (data['name'] as String).trim()
        : 'Circle';
    final List<String> members = _memberIds(data);
    final int memberCount = members.length;
    final List<String> visibleMembers = members.take(4).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(
          '/circle-detail',
          arguments: <String, String>{'familyId': circleDoc.id},
        ),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: palette.border,
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
                        color: palette.textPrimary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                      style: KinCircleTypography.body14(
                        color: palette.textMuted,
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
                                backgroundColor: _avatarColor(entry.key, palette),
                                child: Text(
                                  _initialFromMember(entry.value),
                                  style: KinCircleTypography.caption12(
                                    color: palette.textPrimary,
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
                      color: palette.textMuted,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textMuted,
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
    this.actionLabel = 'Try Again',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
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
                color: palette.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: palette.accent,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: KinCircleTypography.cardTitle16(
                color: palette.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: KinCircleButtons.primary(),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
