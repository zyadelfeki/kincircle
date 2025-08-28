import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

class PlacesService {
  final GoogleMapsPlaces _places;

  PlacesService({required String apiKey})
      : _places = GoogleMapsPlaces(apiKey: apiKey);

  /// Returns a list of Autocomplete [Prediction] for the given [input].
  /// If the input is empty, an empty list is returned immediately.
  Future<List<Prediction>> getAutocompleteSuggestions(String input) async {
    if (input.trim().isEmpty) return [];

    final response = await _places.autocomplete(
      input,
      components: [
        Component(Component.country, 'eg')
      ], // Limit to Egypt by default; change as needed
    );

    if (response.isOkay) {
      return response.predictions;
    } else {
      throw Exception(response.errorMessage ?? 'Unknown Places API error');
    }
  }

  /// Retrieves the exact [LatLng] of a place by its [placeId].
  Future<LatLng> getPlaceDetails(String placeId) async {
    final response = await _places.getDetailsByPlaceId(placeId);
    if (response.isOkay) {
      final loc = response.result.geometry?.location;
      if (loc != null) {
        return LatLng(loc.lat, loc.lng);
      }
      throw Exception('Location not found in place details');
    } else {
      throw Exception(response.errorMessage ?? 'Unknown Places API error');
    }
  }

  /// Disposes the underlying http client.
  void dispose() {
    _places.dispose();
  }
}
