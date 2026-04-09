import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Removed google_maps_webservice in favor of direct HTTP API in PlacesService

import '../../services/places_service.dart';
import '../../services/pro_gating_service.dart';
import '../../services/firestore_service.dart';

/// Screen that allows the user to search for a place using Google Places
/// Autocomplete, preview it on a map, and define/confirm a geofence.
class AddGeofenceScreen extends StatefulWidget {
  const AddGeofenceScreen({super.key});

  @override
  State<AddGeofenceScreen> createState() => _AddGeofenceScreenState();
}

class _AddGeofenceScreenState extends State<AddGeofenceScreen> {
  late final PlacesService _placesService;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  GoogleMapController? _mapController;

  List<PlacePrediction> _suggestions = [];
  Timer? _debounce;

  LatLng _mapCenter = const LatLng(30.0444, 31.2357); // Default Cairo
  final Set<Marker> _markers = {};

  static const int _debounceMilliseconds = 350;

  @override
  void initState() {
    super.initState();
    const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    _placesService = PlacesService(apiKey: apiKey);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _placesService.dispose();
    super.dispose();
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
      final placeId = prediction.placeId; // non-null
      final coords = await _placesService.getPlaceDetails(placeId);
      final desc = prediction.description;
      _nameController.text = desc;

      _markers
        ..clear()
        ..add(Marker(markerId: MarkerId(placeId), position: coords));

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
    return Scaffold(
      appBar: AppBar(title: const Text('Create Geofence')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search location',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Suggestion list
          if (_suggestions.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final p = _suggestions[index];
                  return ListTile(
                    title: Text(p.description),
                    onTap: () => _onSuggestionTap(p),
                  );
                },
              ),
            )
          else
            // Map & form fields
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: GoogleMap(
                      onMapCreated: (c) => _mapController = c,
                      initialCameraPosition:
                          CameraPosition(target: _mapCenter, zoom: 12),
                      markers: _markers,
                      myLocationEnabled: true,
                      zoomGesturesEnabled: true,
                      scrollGesturesEnabled: true,
                      rotateGesturesEnabled: true,
                      tiltGesturesEnabled: true,
                      zoomControlsEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Geofence Name',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 12),
                    child: SizedBox(
                      width: double.infinity,
                       child: ElevatedButton(
                         onPressed: () async {
                           final ctx = context;
                           final messenger = ScaffoldMessenger.of(ctx);
                           final name = _nameController.text.trim();
                           if (name.isEmpty) {
                             messenger.showSnackBar(const SnackBar(content: Text('Please enter a name.')));
                             return;
                           }
                            if (_markers.isEmpty) {
                              messenger.showSnackBar(const SnackBar(content: Text('Please select a location first.')));
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
                             messenger.showSnackBar(const SnackBar(content: Text('Not signed in or no family found.')));
                             return;
                           }
                           try {
                             await FirebaseFirestore.instance.collection('geofences').add({
                                'name': name,
                                'familyId': famId,
                                'userId': uid,
                                'lat': selectedPosition.latitude,
                                'lng': selectedPosition.longitude,
                                'radius': 200.0,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                             if (!ctx.mounted) return;
                             Navigator.of(ctx).pop(true);
                           } catch (e) {
                             if (!ctx.mounted) return;
                             messenger.showSnackBar(SnackBar(content: Text('Failed to save: $e')));
                           }
                         },
                         child: const Text('Save Geofence'),
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
