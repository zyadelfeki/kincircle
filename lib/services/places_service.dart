import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PlacePrediction {
  const PlacePrediction({
    required this.placeId,
    required this.description,
    this.lat,
    this.lng,
  });

  final String placeId;
  final String description;
  final double? lat;
  final double? lng;
}

class PlacesService {
  PlacesService({this.apiKey = '', http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const String _userAgent =
      'KinCircle/1.0 (support: zyadelfeki@std.mans.edu.eg)';

  final Map<String, LatLng> _detailsCache = {};

  /// Returns a list of Autocomplete predictions using Nominatim OpenStreetMap API.
  Future<List<PlacePrediction>> getAutocompleteSuggestions(String input) async {
    final String query = input.trim();
    if (query.isEmpty) return [];

    final String encodedQuery = Uri.encodeComponent(query);
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5',
    );

    final resp = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (resp.statusCode != 200) {
      throw Exception('Search failed with HTTP ${resp.statusCode}');
    }

    final List<dynamic> data = json.decode(resp.body) as List<dynamic>;
    final List<PlacePrediction> predictions = [];

    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final String placeId = item['place_id']?.toString() ?? '';
        final String description = item['display_name'] as String? ?? '';
        final double? lat = double.tryParse(item['lat']?.toString() ?? '');
        final double? lon = double.tryParse(item['lon']?.toString() ?? '');

        if (placeId.isNotEmpty && description.isNotEmpty) {
          if (lat != null && lon != null) {
            _detailsCache[placeId] = LatLng(lat, lon);
          }
          predictions.add(
            PlacePrediction(
              placeId: placeId,
              description: description,
              lat: lat,
              lng: lon,
            ),
          );
        }
      }
    }

    return predictions;
  }

  /// Retrieves the exact [LatLng] of a place by its [placeId].
  Future<LatLng> getPlaceDetails(String placeId) async {
    if (_detailsCache.containsKey(placeId)) {
      return _detailsCache[placeId]!;
    }

    final String encodedPlaceId = Uri.encodeComponent(placeId);
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/details?place_id=$encodedPlaceId&format=json',
    );

    final resp = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );

    if (resp.statusCode != 200) {
      throw Exception('Place details failed: ${resp.statusCode}');
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final dynamic geometry = data['geometry'];
    if (geometry is Map<String, dynamic> && geometry['coordinates'] is List) {
      final List coords = geometry['coordinates'] as List;
      final double lng = (coords[0] as num).toDouble();
      final double lat = (coords[1] as num).toDouble();
      final latLng = LatLng(lat, lng);
      _detailsCache[placeId] = latLng;
      return latLng;
    }

    final double? lat = double.tryParse(data['lat']?.toString() ?? '');
    final double? lon = double.tryParse(data['lon']?.toString() ?? '');
    if (lat != null && lon != null) {
      final latLng = LatLng(lat, lon);
      _detailsCache[placeId] = latLng;
      return latLng;
    }

    throw Exception('Could not resolve coordinates for placeId: $placeId');
  }

  /// Reverse-geocodes coordinates into an address label.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json',
      );
      final resp = await _client.get(
        uri,
        headers: {'User-Agent': _userAgent},
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final String? name = data['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          return name.trim();
        }
        final String? displayName = data['display_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          return displayName.split(',').take(2).join(',').trim();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Reverse geocode error: $e');
      }
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}
