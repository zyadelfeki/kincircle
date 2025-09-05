import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_controller.dart';
import '../widgets/paywall.dart';

class ProGatingService {
  ProGatingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const int freeMemberLimit = 3;
  static const int freeSafeZoneLimit = 1;

  final FirebaseFirestore _firestore;

  bool isPro(BuildContext context) => context.read<ThemeController>().isPro;

  Future<int> countFamilyMembers(String familyId) async {
    final doc = await _firestore.collection('families').doc(familyId).get();
    final familyData = doc.data();
    final members = (familyData?['members'] as List?) ?? const [];
    return members.length;
  }

  Future<int> countSafeZones(String familyId) async {
    final snap = await _firestore
        .collection('geofences')
        .where('familyId', isEqualTo: familyId)
        .get();
    return snap.size;
  }

  Future<bool> ensureCanAddMember(BuildContext context, String familyId) async {
    if (isPro(context)) return true;
    final count = await countFamilyMembers(familyId);
    if (count < freeMemberLimit) return true;
    if (!context.mounted) return false;
    await showSoftPaywall(
      context,
      title: 'Grow your Circle with Pro',
      message:
          'Free includes up to $freeMemberLimit members. Upgrade to KinCircle Pro for unlimited Circle members and more.',
      onStartTrial: () => Navigator.of(context).pushNamed('/paywall'),
    );
    return false;
  }

  Future<bool> ensureCanAddSafeZone(
      BuildContext context, String familyId) async {
    if (isPro(context)) return true;
    final count = await countSafeZones(familyId);
    if (count < freeSafeZoneLimit) return true;
    if (!context.mounted) return false;
    await showSoftPaywall(
      context,
      title: 'More Safe Zones with Pro',
      message:
          'Free includes $freeSafeZoneLimit Safe Zone. Upgrade to Pro for unlimited Safe Zones.',
      onStartTrial: () => Navigator.of(context).pushNamed('/paywall'),
    );
    return false;
  }

  Future<bool> ensureProFeature(BuildContext context, String featureName) async {
    if (isPro(context)) return true;
    if (!context.mounted) return false;
    await showSoftPaywall(
      context,
      title: 'Unlock $featureName',
      message:
          '$featureName is part of KinCircle Pro along with unlimited members, Safe Zones, and more.',
      onStartTrial: () => Navigator.of(context).pushNamed('/subscription'),
    );
    return false;
  }
}
