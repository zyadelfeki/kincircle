import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../design/kincircle_screen_tokens.dart';
import '../../services/places_service.dart';
import '../../services/pro_gating_service.dart';
import '../../services/firestore_service.dart';

class AddGeofenceScreen extends StatefulWidget {
  const AddGeofenceScreen({super.key});

  @override
  State<AddGeofenceScreen> createState() => _AddGeofenceScreenState();
}

class _AddGeofenceScreenState extends State<AddGeofenceScreen> {
  static const String _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"administrative.country","elementType":"geometry.stroke","stylers":[{"color":"#4b6878"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#023e58"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#2c6675"}]},
  {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#3a4762"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]}
]
''';

  late final PlacesService _placesService;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  GoogleMapController? _mapController;

  List<PlacePrediction> _suggestions = [];
  Timer? _debounce;

  LatLng _mapCenter = const LatLng(30.0444, 31.2357);
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  double _radiusMeters = 200.0;

  static const int _debounceMilliseconds = 350;

  @override
  void initState() {
    super.initState();
    _placesService = PlacesService();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _placesService.dispose();
    super.dispose();
  }

  void _updateCircleOverlay(LatLng coords, KinCirclePaletteData palette) {
    _circles
      ..clear()
      ..add(
        Circle(
          circleId: const CircleId('geofence_radius'),
          center: coords,
          radius: _radiusMeters,
          fillColor: palette.accent.withValues(alpha: 0.2),
          strokeColor: palette.accent,
          strokeWidth: 2,
        ),
      );
  }

  void _onMapTap(LatLng coords) async {
    FocusScope.of(context).unfocus();
    final palette = KinCirclePalette.of(context);
    setState(() {
      _mapCenter = coords;
      _markers
        ..clear()
        ..add(Marker(
          markerId: const MarkerId('selected_pin'),
          position: coords,
        ));
      _updateCircleOverlay(coords, palette);
    });

    if (_nameController.text.trim().isEmpty) {
      final String? label = await _placesService.reverseGeocode(
        coords.latitude,
        coords.longitude,
      );
      if (mounted && label != null && _nameController.text.trim().isEmpty) {
        setState(() {
          _nameController.text = label;
        });
      }
    }
  }

  void _onSearchChanged(String input) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: _debounceMilliseconds), () async {
      try {
        final preds = await _placesService.getAutocompleteSuggestions(input);
        if (mounted) {
          setState(() => _suggestions = preds);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Search failed: $e')),
          );
        }
      }
    });
  }

  Future<void> _onSuggestionTap(PlacePrediction prediction) async {
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = []);

    try {
      final placeId = prediction.placeId;
      final coords = await _placesService.getPlaceDetails(placeId);
      if (!mounted) return;
      final desc = prediction.description;
      _nameController.text = desc;

      final palette = KinCirclePalette.of(context);
      _markers
        ..clear()
        ..add(Marker(markerId: MarkerId(placeId), position: coords));
      _updateCircleOverlay(coords, palette);

      setState(() {
        _mapCenter = coords;
      });

      final ctrl = _mapController;
      if (ctrl != null) {
        await ctrl.animateCamera(CameraUpdate.newLatLngZoom(coords, 16));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching place details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = KinCirclePalette.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text(
          'Add safe place',
          style: KinCircleTypography.cardTitle16(color: palette.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              style: KinCircleTypography.body14(color: palette.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search location',
                hintStyle: KinCircleTypography.body14(color: palette.textMuted),
                prefixIcon: Icon(Icons.search, color: palette.textMuted),
                filled: true,
                fillColor: palette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: palette.accent),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_suggestions.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final p = _suggestions[index];
                  return ListTile(
                    title: Text(
                      p.description,
                      style: KinCircleTypography.body14(color: palette.textPrimary),
                    ),
                    tileColor: palette.surface,
                    onTap: () => _onSuggestionTap(p),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: GoogleMap(
                      onMapCreated: (c) => _mapController = c,
                      initialCameraPosition:
                          CameraPosition(target: _mapCenter, zoom: 12),
                      style: isDark ? _darkMapStyle : null,
                      markers: _markers,
                      circles: _circles,
                      onTap: _onMapTap,
                      myLocationEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      zoomControlsEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    color: palette.surface,
                    child: Row(
                      children: [
                        Text(
                          'Radius: ${_radiusMeters.round()}m',
                          style: KinCircleTypography.body14(
                            color: palette.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _radiusMeters,
                            min: 50.0,
                            max: 1000.0,
                            divisions: 19,
                            activeColor: palette.accent,
                            label: '${_radiusMeters.round()}m',
                            onChanged: (val) {
                              setState(() {
                                _radiusMeters = val;
                                if (_markers.isNotEmpty) {
                                  _updateCircleOverlay(_markers.first.position, palette);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _nameController,
                      style: KinCircleTypography.body14(color: palette.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Place name',
                        labelStyle: KinCircleTypography.caption12(color: palette.textMuted),
                        filled: true,
                        fillColor: palette.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: palette.border),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: KinCircleButtons.primary(),
                        onPressed: () async {
                          final ctx = context;
                          final messenger = ScaffoldMessenger.of(ctx);
                          final name = _nameController.text.trim();
                          if (name.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Please enter a place name.')),
                            );
                            return;
                          }
                          if (_markers.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Please select a location on the map first.')),
                            );
                            return;
                          }
                          final LatLng selectedPosition = _markers.first.position;
                          final famId = await FirestoreService().getCurrentFamilyId();
                          if (!ctx.mounted) return;
                          if (famId != null) {
                            final ok = await ProGatingService().ensureCanAddSafeZone(ctx, famId);
                            if (!ctx.mounted) return;
                            if (!ok) return;
                          }
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          if (uid == null || famId == null) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Not signed in or no family found.')),
                            );
                            return;
                          }
                          try {
                            await FirebaseFirestore.instance.collection('geofences').add({
                              'name': name,
                              'familyId': famId,
                              'userId': uid,
                              'lat': selectedPosition.latitude,
                              'lng': selectedPosition.longitude,
                              'radius': _radiusMeters,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop(true);
                          } catch (e) {
                            if (!ctx.mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to save: $e')),
                            );
                          }
                        },
                        child: const Text('Save place'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
