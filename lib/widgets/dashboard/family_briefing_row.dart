import 'package:flutter/material.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../models/user_model.dart';
import '../../services/family_snapshot_service.dart';
import '../../utils/time_utils.dart';

class FamilyBriefingRow extends StatefulWidget {
  const FamilyBriefingRow({
    super.key,
    required this.familyId,
    required this.members,
    this.now,
    this.onSeeAll,
    this.onCheckIn,
  });

  final String familyId;
  final List<AppUser> members;
  final DateTime? now;
  final VoidCallback? onSeeAll;
  final VoidCallback? onCheckIn;

  @override
  State<FamilyBriefingRow> createState() => _FamilyBriefingRowState();
}

class _FamilyBriefingRowState extends State<FamilyBriefingRow> {
  late FamilySnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _computeSnapshot();
  }

  @override
  void didUpdateWidget(covariant FamilyBriefingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members != widget.members ||
        oldWidget.now != widget.now ||
        oldWidget.familyId != widget.familyId) {
      _computeSnapshot();
    }
  }

  void _computeSnapshot() {
    _snapshot = FamilySnapshot.fromMembers(
      members: widget.members,
      now: widget.now,
    );
  }

  void _showMembersSheet({
    required BuildContext context,
    required String title,
    required List<AppUser> members,
    required Color accentColor,
    bool isNeedsHelp = false,
  }) {
    final palette = KinCirclePalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isNeedsHelp
                            ? Icons.warning_amber_rounded
                            : Icons.people_outline_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$title (${members.length})',
                        style: KinCircleTypography.cardTitle16(
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No members in this category',
                        style: KinCircleTypography.body14(
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: members.length,
                      separatorBuilder: (_, __) => Divider(
                        color: palette.border.withValues(alpha: 0.5),
                        height: 1,
                      ),
                      itemBuilder: (BuildContext _, int index) {
                        final AppUser member = members[index];
                        final String timeStr = member.lastUpdated != null
                            ? formatRelativeTime(member.lastUpdated!)
                            : 'Unknown';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: accentColor.withValues(alpha: 0.18),
                                child: Text(
                                  _initials(member.displayName),
                                  style: KinCircleTypography.caption12(
                                    color: palette.textPrimary,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.displayName.trim().isNotEmpty
                                          ? member.displayName
                                          : 'Unknown',
                                      style: KinCircleTypography.body14(
                                        color: palette.textPrimary,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Updated $timeStr',
                                      style: KinCircleTypography.caption12(
                                        color: palette.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isNeedsHelp)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.of(sheetContext).pop();
                                    if (widget.onCheckIn != null) {
                                      widget.onCheckIn!();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Checking in on ${member.displayName}…'),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.error,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    textStyle: KinCircleTypography.caption12(
                                      weight: FontWeight.w700,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle_outline, size: 14),
                                  label: const Text('Check in'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _initials(String displayName) {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return ''.toUpperCase();
  }

  Widget _buildCard({
    required BuildContext context,
    required Key key,
    required String countText,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final palette = KinCirclePalette.of(context);
    return Expanded(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: KinCircleRadii.card,
            border: Border.all(color: palette.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        countText,
                        style: KinCircleTypography.caption12(
                          color: color,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(icon, color: color, size: 16),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: KinCircleTypography.caption12(
                    color: palette.textPrimary,
                    weight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: KinCircleTypography.caption10(
                    color: palette.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    final bool hasNeedsHelp = _snapshot.needsHelpCount > 0;

    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasNeedsHelp) ...[
            _buildCard(
              context: context,
              key: const Key('briefing_card_needsHelp'),
              countText: '${_snapshot.needsHelpCount}',
              title: '${_snapshot.needsHelpCount} need help',
              subtitle: 'Tap to view',
              icon: Icons.warning_amber_rounded,
              color: palette.error,
              onTap: () => _showMembersSheet(
                context: context,
                title: 'Needs Help',
                members: _snapshot.needsHelpMembers,
                accentColor: palette.error,
                isNeedsHelp: true,
              ),
            ),
            const SizedBox(width: 8),
          ],
          _buildCard(
            context: context,
            key: const Key('briefing_card_safe'),
            countText: '${_snapshot.safeCount}',
            title: '${_snapshot.safeCount} safe',
            subtitle: 'All accounted for',
            icon: Icons.check_circle_outline_rounded,
            color: palette.success,
            onTap: () => _showMembersSheet(
              context: context,
              title: 'Safe Members',
              members: _snapshot.safeMembers,
              accentColor: palette.success,
            ),
          ),
          const SizedBox(width: 8),
          _buildCard(
            context: context,
            key: const Key('briefing_card_moving'),
            countText: '${_snapshot.movingCount}',
            title: '${_snapshot.movingCount} moving',
            subtitle: 'En route / active',
            icon: Icons.navigation_outlined,
            color: palette.warning,
            onTap: () => _showMembersSheet(
              context: context,
              title: 'Moving Members',
              members: _snapshot.movingMembers,
              accentColor: palette.warning,
            ),
          ),
          const SizedBox(width: 8),
          _buildCard(
            context: context,
            key: const Key('briefing_card_stale'),
            countText: '${_snapshot.staleCount}',
            title: '${_snapshot.staleCount} stale',
            subtitle: 'No recent update',
            icon: Icons.access_time_rounded,
            color: palette.textMuted,
            onTap: () => _showMembersSheet(
              context: context,
              title: 'Stale Members',
              members: _snapshot.staleMembers,
              accentColor: palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
