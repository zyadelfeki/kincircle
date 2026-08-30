import '../models/user_model.dart';

/// Snapshot containing member counts and filtered lists classified by status
class FamilySnapshot {
  final List<AppUser> members;
  final int safeCount;
  final int movingCount;
  final int staleCount;
  final int needsHelpCount;
  final List<AppUser> safeMembers;
  final List<AppUser> movingMembers;
  final List<AppUser> staleMembers;
  final List<AppUser> needsHelpMembers;

  const FamilySnapshot({
    required this.members,
    required this.safeCount,
    required this.movingCount,
    required this.staleCount,
    required this.needsHelpCount,
    required this.safeMembers,
    required this.movingMembers,
    required this.staleMembers,
    required this.needsHelpMembers,
  });

  factory FamilySnapshot.fromMembers({
    required List<AppUser> members,
    DateTime? now,
  }) {
    final DateTime currentNow = now ?? DateTime.now();
    final List<AppUser> safe = <AppUser>[];
    final List<AppUser> moving = <AppUser>[];
    final List<AppUser> stale = <AppUser>[];
    final List<AppUser> needsHelp = <AppUser>[];

    for (final AppUser member in members) {
      final String category = FamilySnapshotService.classifyMember(member, currentNow);
      switch (category) {
        case 'needsHelp':
          needsHelp.add(member);
          break;
        case 'stale':
          stale.add(member);
          break;
        case 'moving':
          moving.add(member);
          break;
        case 'safe':
        default:
          safe.add(member);
          break;
      }
    }

    return FamilySnapshot(
      members: members,
      safeCount: safe.length,
      movingCount: moving.length,
      staleCount: stale.length,
      needsHelpCount: needsHelp.length,
      safeMembers: safe,
      movingMembers: moving,
      staleMembers: stale,
      needsHelpMembers: needsHelp,
    );
  }
}

/// Service providing classification and snapshot aggregation for family circle members
class FamilySnapshotService {
  /// Pure helper to classify a member into: 'needsHelp' | 'moving' | 'safe' | 'stale'
  static String classifyMember(AppUser member, DateTime now) {
    if (member.needsHelp == true) {
      return 'needsHelp';
    }
    if (member.lastUpdated == null ||
        now.difference(member.lastUpdated!).inHours >= 3) {
      return 'stale';
    }
    if (member.lastKnownLocation != null &&
        now.difference(member.lastUpdated!).inMinutes <= 15) {
      return 'moving';
    }
    return 'safe';
  }

  /// Calculates and returns a FamilySnapshot for a family's members
  static Future<FamilySnapshot> getSnapshot({
    required String familyId,
    required List<AppUser> members,
    DateTime? now,
  }) async {
    return FamilySnapshot.fromMembers(
      members: members,
      now: now,
    );
  }
}

/// Top-level pure helper matching classifyMember
String classifyMember(AppUser member, DateTime now) =>
    FamilySnapshotService.classifyMember(member, now);
