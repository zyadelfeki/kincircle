import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../models/user_model.dart';
import '../../services/streak_service.dart';

class FamilyLeaderboardWidget extends StatefulWidget {
  const FamilyLeaderboardWidget({
    super.key,
    required this.familyId,
    this.circleName,
  });

  final String familyId;
  final String? circleName;

  @override
  State<FamilyLeaderboardWidget> createState() =>
      _FamilyLeaderboardWidgetState();
}

class _FamilyLeaderboardWidgetState extends State<FamilyLeaderboardWidget> {
  final StreakService _streakService = StreakService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  List<LeaderboardEntry> _entries = <LeaderboardEntry>[];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  @override
  void didUpdateWidget(covariant FamilyLeaderboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyId != widget.familyId) {
      _loadLeaderboard();
    }
  }

  Future<void> _loadLeaderboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Fetch circle members from users collection
      final QuerySnapshot<Map<String, dynamic>> userSnap = await _firestore
          .collection('users')
          .where('currentFamilyId', isEqualTo: widget.familyId)
          .get();

      List<AppUser> members =
          userSnap.docs.map(AppUser.fromFirestore).toList();

      // If no users found by currentFamilyId query, fallback to family doc members array
      if (members.isEmpty) {
        final DocumentSnapshot<Map<String, dynamic>> famDoc = await _firestore
            .collection('families')
            .doc(widget.familyId)
            .get();
        final List<dynamic> memberUids =
            famDoc.data()?['members'] as List<dynamic>? ?? <dynamic>[];

        for (final dynamic rawUid in memberUids) {
          final String uid = rawUid.toString();
          if (uid.isEmpty) continue;
          final DocumentSnapshot<Map<String, dynamic>> uDoc =
              await _firestore.collection('users').doc(uid).get();
          if (uDoc.exists && uDoc.data() != null) {
            members.add(AppUser.fromFirestore(uDoc));
          } else {
            members.add(AppUser(
              uid: uid,
              displayName: 'Family Member',
              photoURL: '',
              isInvisible: false,
            ));
          }
        }
      }

      // 2. Fetch real streaks for each member
      final List<LeaderboardEntry> entries =
          await _streakService.getFamilyLeaderboard(
        familyId: widget.familyId,
        members: members,
      );

      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      debugPrint('FamilyLeaderboardWidget load error: ');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load leaderboard';
      });
    }
  }

  Widget _buildRankBadge(int rank, KinCirclePaletteData palette) {
    if (rank == 1) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.amber, width: 1.5),
        ),
        child: const Center(
          child: Text('🥇', style: TextStyle(fontSize: 14)),
        ),
      );
    } else if (rank == 2) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey, width: 1.5),
        ),
        child: const Center(
          child: Text('🥈', style: TextStyle(fontSize: 14)),
        ),
      );
    } else if (rank == 3) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.brown.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.brown, width: 1.5),
        ),
        child: const Center(
          child: Text('🥉', style: TextStyle(fontSize: 14)),
        ),
      );
    }

    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      child: Text(
        '#',
        style: KinCircleTypography.caption12(
          color: palette.textMuted,
          weight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);

    if (_loading) {
      return Shimmer.fromColors(
        baseColor: palette.surfaceAlt,
        highlightColor: palette.border,
        child: Container(
          height: 160,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      );
    }

    if (_error != null) {
      return const SizedBox.shrink();
    }

    // Check if anyone has check-ins (at least 1 day streak or longest streak > 0)
    final bool hasAnyStreak = _entries.any(
        (e) => e.currentStreak > 0 || e.longestStreak > 0 || e.checkedInToday);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.circleName != null && widget.circleName!.isNotEmpty
                      ? ' Streaks'
                      : 'Streak Leaderboard',
                  style: KinCircleTypography.cardTitle16(
                    color: palette.textPrimary,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: palette.textMuted,
                tooltip: 'Refresh',
                onPressed: _loadLeaderboard,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasAnyStreak)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No streaks yet — be the first to check in today.',
                  style: KinCircleTypography.body14(color: palette.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _entries.length,
              separatorBuilder: (_, __) => Divider(
                color: palette.border.withValues(alpha: 0.5),
                height: 16,
              ),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final rank = index + 1;
                final String initial = entry.member.displayName.isNotEmpty
                    ? entry.member.displayName.substring(0, 1).toUpperCase()
                    : '?';

                return Row(
                  children: [
                    _buildRankBadge(rank, palette),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: palette.accent.withValues(alpha: 0.2),
                      backgroundImage: entry.member.photoURL.isNotEmpty
                          ? NetworkImage(entry.member.photoURL)
                          : null,
                      child: entry.member.photoURL.isEmpty
                          ? Text(
                              initial,
                              style: KinCircleTypography.caption12(
                                color: palette.accent,
                                weight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.member.displayName,
                            style: KinCircleTypography.body14(
                              color: palette.textPrimary,
                              weight: FontWeight.w600,
                            ),
                          ),
                          if (entry.longestStreak > entry.currentStreak)
                            Text(
                              'Best:  days',
                              style: KinCircleTypography.caption12(
                                color: palette.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: entry.currentStreak > 0
                            ? Colors.orange.withValues(alpha: 0.15)
                            : palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: entry.currentStreak > 0
                              ? Colors.orange.withValues(alpha: 0.3)
                              : palette.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.currentStreak > 0 ? '🔥' : '⏳',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'd',
                            style: KinCircleTypography.caption12(
                              color: entry.currentStreak > 0
                                  ? Colors.orange.shade700
                                  : palette.textMuted,
                              weight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
