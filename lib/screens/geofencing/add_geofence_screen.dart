import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

import '../../services/places_service.dart';

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

  List<Prediction> _suggestions = [];
  Timer? _debounce;

  LatLng _mapCenter = const LatLng(30.0444, 31.2357); // Default Cairo
  final Set<Marker> _markers = {};

  static const int _debounceMilliseconds = 350;

  @override
  void initState() {
    super.initState();
    // Ideally, the API key should come from secure storage / Remote Config.
    const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY',
        defaultValue: 'YOUR_GOOGLE_MAPS_API_KEY');
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
        // Silently ignore for now; you might show a SnackBar instead.
      }
    });
  }

  Future<void> _onSuggestionTap(Prediction prediction) async {
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = []);

    try {
      final coords = await _placesService.getPlaceDetails(prediction.placeId!);
      _nameController.text = prediction.description ?? '';

      _markers
        ..clear()
        ..add(
            Marker(markerId: MarkerId(prediction.placeId!), position: coords));

      setState(() {
        _mapCenter = coords;
      });

      await _mapController
          ?.animateCamera(CameraUpdate.newLatLngZoom(coords, 16));
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
                    title: Text(p.description ?? ''),
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
                        onPressed: () {
                          // TODO: Save geofence to Firestore
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
 