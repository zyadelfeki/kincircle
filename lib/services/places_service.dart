import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PlacePrediction {
  const PlacePrediction({required this.placeId, required this.description});
  final String placeId;
  final String description;
}

class PlacesService {
  PlacesService({required this.apiKey});
  final String apiKey;

  /// Returns a list of Autocomplete [Prediction] for the given [input].
  /// If the input is empty, an empty list is returned immediately.
  Future<List<PlacePrediction>> getAutocompleteSuggestions(String input) async {
    if (input.trim().isEmpty) return [];

    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': input,
      'key': apiKey,
      'components': 'country:eg',
    });
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Places autocomplete failed: ${resp.statusCode}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      final err = data['error_message'] ?? data['status'];
      throw Exception('Places autocomplete error: $err');
    }
    final preds = (data['predictions'] as List)
        .cast<Map<String, dynamic>>()
        .map((p) => PlacePrediction(
              placeId: p['place_id'] as String,
              description: p['description'] as String,
            ))
        .toList();
    return preds;
  }

  /// Retrieves the exact [LatLng] of a place by its [placeId].
  Future<LatLng> getPlaceDetails(String placeId) async {
    final uri =
        Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'fields': 'geometry/location',
      'key': apiKey,
    });
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Place details failed: ${resp.statusCode}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') {
      final err = data['error_message'] ?? data['status'];
      throw Exception('Place details error: $err');
    }
    final result = data['result'] as Map<String, dynamic>;
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    final lat = (location['lat'] as num).toDouble();
    final lng = (location['lng'] as num).toDouble();
    return LatLng(lat, lng);
  }

  /// Disposes the underlying http client.
  void dispose() {
    // no-op for http
  }
}
