import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../models/user_model.dart';
import '../../widgets/nav_shell.dart';
import '../../widgets/dashboard/active_alerts_card.dart';
import '../../widgets/dashboard/battery_overview_card.dart';
import '../../widgets/dashboard/dashboard_card_container.dart';
import '../../widgets/dashboard/dashboard_card_shimmer.dart';
import '../../widgets/dashboard/family_online_card.dart';
import '../../widgets/dashboard/family_rhythms_card.dart';
import '../../widgets/dashboard/quick_actions_card.dart';
import '../../widgets/dashboard/recent_activity_card.dart';
import '../../widgets/dashboard/rhythm_teaser_card.dart';
import '../../widgets/dashboard/safe_places_card.dart';
import '../../widgets/battery_shield_card.dart';
import '../../widgets/dashboard/check_in_card.dart';
import '../../services/pending_invite_store.dart';
import '../../services/streak_service.dart';
import '../../services/theme_controller.dart';
import '../../widgets/celebration_widgets.dart';
import '../../widgets/location_permission_banner.dart';
import '../family/accept_invite_screen.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;

  String? _familyId;
  List<AppUser> _members = <AppUser>[];
  int _activeAlertCount = 0;
  String? _lastAlertMessage;
  int _safePlacesCount = 0;
  List<RecentActivityItem> _recentActivity = <RecentActivityItem>[];
  AppUser? _lowestBatteryMember;
  int? _lowestBattery;
  bool _checkedInToday = false;
  int _currentStreak = 0;
  bool _isCheckingIn = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _alertsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _geofencesSub;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        _alertsSub?.cancel();
        _alertsSub = null;
        _membersSub?.cancel();
        _membersSub = null;
        _geofencesSub?.cancel();
        _geofencesSub = null;
      }
    });
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final pendingStore =
            Provider.of<PendingInviteStore>(context, listen: false);
        final inviteId = await pendingStore.consume();
        if (inviteId != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AcceptInviteScreen(inviteId: inviteId),
            ),
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _alertsSub?.cancel();
    _membersSub?.cancel();
    _geofencesSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Please sign in to view dashboard.';
        });
        return;
      }

      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final String? familyId = userDoc.data()?['currentFamilyId'] as String?;

      if (familyId == null || familyId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _familyId = null;
          _members = <AppUser>[];
          _safePlacesCount = 0;
          _activeAlertCount = 0;
          _lastAlertMessage = null;
          _recentActivity = <RecentActivityItem>[];
          _lowestBatteryMember = null;
          _lowestBattery = null;
          _loading = false;
        });
        return;
      }

      _familyId = familyId;

      final results = await Future.wait([
        _firestore
            .collection('users')
            .where('currentFamilyId', isEqualTo: familyId)
            .get(),
        _firestore
            .collection('geofences')
            .where('familyId', isEqualTo: familyId)
            .get(),
        _firestore
            .collection('alerts')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .limit(5)
            .get(),
      ]);

      final QuerySnapshot<Map<String, dynamic>> memberSnap = results[0];
      final QuerySnapshot<Map<String, dynamic>> geofenceSnap = results[1];
      final QuerySnapshot<Map<String, dynamic>> activitySnap = results[2];

      final List<AppUser> members =
          memberSnap.docs.map(AppUser.fromFirestore).toList();
      final List<RecentActivityItem> activity =
          activitySnap.docs.map(_toActivityItem).toList();

      final List<_BatteryTuple> batteryTuples = members
          .where((m) => m.batteryLevel != null)
          .map((AppUser member) => _BatteryTuple(member, member.batteryLevel!))
          .toList();
      batteryTuples.sort((a, b) => a.battery.compareTo(b.battery));

      if (!mounted) return;
      setState(() {
        _members = members;
        _safePlacesCount = geofenceSnap.size;
        _recentActivity = activity;
        _lowestBatteryMember = batteryTuples.isNotEmpty
            ? batteryTuples.first.member
            : (members.isNotEmpty ? members.first : null);
        _lowestBattery =
            batteryTuples.isNotEmpty ? batteryTuples.first.battery : null;
        _loading = false;
      });

      _subscribeToMembers(familyId);
      _subscribeToSafePlaces(familyId);
      _subscribeToActiveAlerts(user.uid);
      _loadCheckInStatus();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      String msg = 'Something went wrong. Please try again.';
      if (e.code == 'permission-denied') {
        msg = 'Something went wrong. Please try again.';
      } else if (e.code == 'failed-precondition') {
        msg = 'Something went wrong. Please try again.';
      }
      debugPrint('DashboardScreen error: \${e.code} \${e.message}');
      setState(() {
        _loading = false;
        _error = msg;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('DashboardScreen unexpected error: $e');
      setState(() {
        _loading = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  void _subscribeToMembers(String familyId) {
    _membersSub?.cancel();
    _membersSub = _firestore
        .collection('users')
        .where('currentFamilyId', isEqualTo: familyId)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      final List<AppUser> members =
          snapshot.docs.map(AppUser.fromFirestore).toList();
      final List<_BatteryTuple> batteryTuples = members
          .where((m) => m.batteryLevel != null)
          .map((AppUser member) => _BatteryTuple(member, member.batteryLevel!))
          .toList()
        ..sort((a, b) => a.battery.compareTo(b.battery));

      if (!mounted) return;
      setState(() {
        _members = members;
        _lowestBatteryMember = batteryTuples.isNotEmpty
            ? batteryTuples.first.member
            : (members.isNotEmpty ? members.first : null);
        _lowestBattery =
            batteryTuples.isNotEmpty ? batteryTuples.first.battery : null;
      });
    }, onError: (_) {});
  }

  void _subscribeToSafePlaces(String familyId) {
    _geofencesSub?.cancel();
    _geofencesSub = _firestore
        .collection('geofences')
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      if (!mounted) return;
      setState(() {
        _safePlacesCount = snapshot.size;
      });
    }, onError: (_) {});
  }

  void _subscribeToActiveAlerts(String userId) {
    _alertsSub?.cancel();
    _alertsSub = _firestore
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {
      int unseen = 0;
      String? preview;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final bool seen = data['seen'] as bool? ?? false;
        if (!seen) unseen++;
      }
      if (snapshot.docs.isNotEmpty) {
        preview = snapshot.docs.first.data()['message'] as String?;
      }
      if (!mounted) return;
      setState(() {
        _activeAlertCount = unseen;
        _lastAlertMessage = preview;
      });
    }, onError: (_) {});
  }

  Future<void> _loadCheckInStatus() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final streak = await StreakService.instance.getUserStreak(
        uid: user.uid,
        familyId: _familyId,
      );
      if (!mounted) return;
      setState(() {
        _checkedInToday = streak.checkedInToday;
        _currentStreak = streak.currentStreak;
      });
    } catch (_) {}
  }

  Future<void> _handleCheckIn() async {
    final user = _auth.currentUser;
    if (user == null || _familyId == null) return;
    setState(() => _isCheckingIn = true);

    try {
      final otherMemberIds = _members
          .map((m) => m.uid)
          .where((uid) => uid != user.uid)
          .toList();

      final result = await StreakService.instance.checkIn(
        uid: user.uid,
        familyId: _familyId!,
        displayName: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Family Member',
        otherFamilyMemberIds: otherMemberIds,
      );

      if (!mounted) return;
      setState(() {
        _checkedInToday = true;
        _currentStreak = result.newStreak;
        _isCheckingIn = false;
      });

      if (result.celebratedMilestone != null && mounted) {
        _showMilestoneCelebration(result.celebratedMilestone!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to check in: $e')),
        );
      }
    }
  }

  void _showMilestoneCelebration(int milestone) {
    showDialog<void>(
      context: context,
      builder: (ctx) => CommunityCelebrationDialog(
        achievement: '$milestone-Day Check-in Streak! 🔥',
        communityCount: milestone,
        socialProof: 'Your circle is celebrating your consistency!',
        companionMessage:
            'Incredible dedication! You have kept your family updated for $milestone consecutive days.',
      ),
    );
  }

  RecentActivityItem _toActivityItem(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    final String title = data['title'] as String? ?? 'Family event';
    final String message = data['message'] as String? ?? 'Update received';
    final DateTime? ts = (data['timestamp'] as Timestamp?)?.toDate();
    final String type = data['type'] as String? ?? '';

    IconData icon = Icons.info_outline;
    if (type.contains('arrival')) {
      icon = Icons.login_rounded;
    } else if (type.contains('departure')) {
      icon = Icons.logout_rounded;
    } else if (type.contains('sos')) {
      icon = Icons.sos_rounded;
    } else if (type.contains('geofence')) {
      icon = Icons.place_outlined;
    } else if (type.contains('pattern') || type.contains('rhythm')) {
      icon = Icons.schedule_rounded;
    }

    return RecentActivityItem(
      title: title,
      subtitle: message,
      timeLabel: _relativeTime(ts),
      icon: icon,
    );
  }

  String _relativeTime(DateTime? dt) {
    if (dt == null) return 'Now';
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  List<AppUser> _onlineMembers() {
    final DateTime now = DateTime.now();
    final String? currentUid = _auth.currentUser?.uid;
    return _members.where((AppUser m) {
      if (m.uid == currentUid) return true;
      final DateTime? updated = m.lastUpdated;
      if (updated == null) return false;
      return now.difference(updated).inMinutes <= 20;
    }).toList();
  }

  Widget _buildShimmerLayout() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
          sliver: SliverToBoxAdapter(
            child: DashboardCardShimmer(height: 106),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: const [
              DashboardCardShimmer(height: 110),
              DashboardCardShimmer(height: 110),
              DashboardCardShimmer(height: 110),
              DashboardCardShimmer(height: 110),
            ],
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
          sliver: SliverToBoxAdapter(
            child: DashboardCardShimmer(height: 180),
          ),
        ),
      ],
    );
  }

  Widget _buildNoFamilyState() {
    final palette = KinCirclePalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, size: 54, color: palette.textMuted),
            const SizedBox(height: 12),
            Text(
              'No circle yet',
              style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a circle to start viewing family activity.',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(color: palette.textMuted),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/create-family'),
              style: KinCircleButtons.primary(),
              child: const Text('Create a circle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return _ErrorState(
      title: 'Something went wrong',
      message: _error ?? 'Please try again.',
      onRetry: _load,
    );
  }

  Widget _buildDashboard() {
    final List<AppUser> online = _onlineMembers();
    final bool isPro = context.watch<ThemeController>().isPro;
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            sliver: SliverToBoxAdapter(
              child: ActiveAlertsCard(
                count: _activeAlertCount,
                lastPreview: _lastAlertMessage,
                onTap: () => Navigator.of(context).pushNamed('/alerts'),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
              child: CheckInCard(
                checkedInToday: _checkedInToday,
                currentStreak: _currentStreak,
                onCheckIn: _handleCheckIn,
                isLoading: _isCheckingIn,
              ),
            ),
          ),
          if (!isPro)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverToBoxAdapter(
                child: RhythmTeaserCard(),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.2,
              ),
              delegate: SliverChildListDelegate.fixed([
                FamilyOnlineCard(
                  onlineMembers: online,
                  totalCount: _members.length,
                ),
                SafePlacesCard(
                  count: _safePlacesCount,
                  onTap: () => Navigator.of(context).pushNamed('/places'),
                ),
                BatteryOverviewCard(
                  member: _lowestBatteryMember,
                  percent: _lowestBattery,
                ),
                QuickActionsCard(
                  onSosTap: () => Navigator.of(context).pushNamed('/alerts'),
                  onShareTap: () => Navigator.of(context).pushNamed('/map'),
                  onAddPlaceTap: () =>
                      Navigator.of(context).pushNamed('/add-geofence'),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: FamilyRhythmsCard(members: _members),
            ),
          ),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: BatteryShieldCard(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: RecentActivityCard(items: _recentActivity),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: _buildAiWellbeingCard(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: _buildStatusSummary(online),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary(List<AppUser> online) {
    final palette = KinCirclePalette.of(context);
    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status summary',
            style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Circle members: ${_members.length}\n'
            'Online now: ${online.length}\n'
            'Safe places: $_safePlacesCount',
            style: KinCircleTypography.body14(color: palette.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAiWellbeingCard() {
    final palette = KinCirclePalette.of(context);
    return DashboardCardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI & wellbeing',
            style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
          ),
          const SizedBox(height: 8),
          _buildNavRow(
            icon: Icons.smart_toy_outlined,
            title: 'AI companion',
            route: '/companion/select',
          ),
          const Divider(height: 1),
          _buildNavRow(
            icon: Icons.analytics_outlined,
            title: 'Family wellbeing',
            route: '/analytics/wellbeing',
          ),
          const Divider(height: 1),
          _buildNavRow(
            icon: Icons.forum_outlined,
            title: 'Emotion feed',
            route: '/community/feed',
          ),
        ],
      ),
    );
  }

  Widget _buildNavRow({
    required IconData icon,
    required String title,
    required String route,
  }) {
    final palette = KinCirclePalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.of(context).pushNamed(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: KinCircleTypography.body14(
                  color: palette.textPrimary,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    Widget content;
    if (_loading) {
      content = _buildShimmerLayout();
    } else if (_error != null) {
      content = _buildErrorState();
    } else if (_familyId == null) {
      content = _buildNoFamilyState();
    } else {
      content = _buildDashboard();
    }

    return Column(
      children: [
        LocationPermissionBanner(
          onPermissionGranted: () {
            _load();
          },
        ),
        Expanded(child: content),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavShell(
      currentIndex: 1,
      title: 'Circles Dashboard',
      body: _buildBody(),
    );
  }
}

class _BatteryTuple {
  const _BatteryTuple(this.member, this.battery);

  final AppUser member;
  final int battery;
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
              style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(color: palette.textMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: KinCircleButtons.primary(),
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
