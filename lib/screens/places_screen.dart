import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Please sign in.';
        });
        return;
      }
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(uid).get();
      final String? familyId = userDoc.data()?['currentFamilyId'] as String?;
      if (familyId == null || familyId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _places = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        });
        return;
      }
      final QuerySnapshot<Map<String, dynamic>> geofences = await _firestore
          .collection('geofences')
          .where('familyId', isEqualTo: familyId)
          .orderBy('createdAt', descending: true)
          .get();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _places = geofences.docs;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load places';
      });
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: KinCirclePalette.error, size: 50),
            const SizedBox(height: 10),
            Text(
              _error ?? 'An error occurred',
              style: KinCircleTypography.body14(color: KinCirclePalette.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: KinCircleButtons.primary(),
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
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
