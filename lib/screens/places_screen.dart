import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../design/kincircle_screen_tokens.dart';
import '../widgets/nav_shell.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _places = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() { _loading = false; _error = 'Please sign in.'; });
        return;
      }
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(uid).get();
      final String? familyId = userDoc.data()?['currentFamilyId'] as String?;
      if (familyId == null || familyId.isEmpty) {
        if (!mounted) return;
        setState(() { _loading = false; _places = []; });
        return;
      }
      // NOTE: orderBy('createdAt') requires a composite index in Firestore.
      // If the index is missing this will throw. Deploy firestore.indexes.json first.
      final QuerySnapshot<Map<String, dynamic>> geofences = await _firestore
          .collection('geofences')
          .where('familyId', isEqualTo: familyId)
          .orderBy('createdAt', descending: true)
          .get();
      if (!mounted) return;
      setState(() { _loading = false; _places = geofences.docs; });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      String msg = 'Unable to load places';
      if (e.code == 'permission-denied') msg = 'Permission denied. Check Firestore rules.';
      if (e.code == 'failed-precondition') msg = 'Missing Firestore index. See logs for index creation link.';
      debugPrint('PlacesScreen error: ${e.code} — ${e.message}');
      setState(() { _loading = false; _error = msg; });
    } catch (e) {
      if (!mounted) return;
      debugPrint('PlacesScreen unexpected error: $e');
      setState(() { _loading = false; _error = 'Unable to load places'; });
    }
  }

  Widget _loadingView() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (_, int index) {
        return Shimmer.fromColors(
          baseColor: KinCirclePalette.surfaceAlt,
          highlightColor: KinCirclePalette.border,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            height: 74,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place_outlined, color: KinCirclePalette.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'No safe places yet',
              style: KinCircleTypography.cardTitle16(),
            ),
            const SizedBox(height: 6),
            Text(
              'Create your first safe place so your circle gets arrival and departure updates.',
              textAlign: TextAlign.center,
              style: KinCircleTypography.body14(color: KinCirclePalette.textMuted),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              style: KinCircleButtons.primary(),
              onPressed: () => Navigator.of(context).pushNamed('/add-geofence'),
              child: const Text('Add Place'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return _ErrorState(
      title: 'Unable to load places',
      message: _error ?? 'Check your connection or permissions.',
      onRetry: _load,
    );
  }

  Widget _listView() {
    if (_places.isEmpty) return _emptyView();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 18),
        itemCount: _places.length + 1,
        itemBuilder: (_, int index) {
          if (index == _places.length) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: OutlinedButton(
                style: KinCircleButtons.secondary(),
                onPressed: () => Navigator.of(context).pushNamed('/add-geofence'),
                child: const Text('Add Place'),
              ),
            );
          }
          final Map<String, dynamic> data = _places[index].data();
          final String name = data['name'] as String? ?? 'Safe Place';
          final String lat = (data['lat'] ?? data['latitude'] ?? '--').toString();
          final String lng = (data['lng'] ?? data['longitude'] ?? '--').toString();
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KinCirclePalette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KinCirclePalette.border, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_rounded, color: KinCirclePalette.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: KinCircleTypography.body14(weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: $lat • Lng: $lng',
                        style: KinCircleTypography.caption12(color: KinCirclePalette.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = _loadingView();
    } else if (_error != null) {
      body = _errorView();
    } else {
      body = _listView();
    }

    return NavShell(
      currentIndex: 2,
      title: 'Places',
      body: body,
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
              decoration: const BoxDecoration(
                color: Color(0xFF1E2440),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFF00C9A7),
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8A8FA8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C9A7),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
