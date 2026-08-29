import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kincircle/services/places_service.dart';

void main() {
  test('PlacesService search maps Nominatim results to PlacePredictions', () async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/search') {
        final sampleResponse = [
          {
            'place_id': 123456,
            'display_name': 'Cairo Tower, Cairo, Egypt',
            'lat': '30.0459',
            'lon': '31.2243',
          },
          {
            'place_id': 789012,
            'display_name': 'Tahrir Square, Cairo, Egypt',
            'lat': '30.0444',
            'lon': '31.2357',
          }
        ];
        return http.Response(json.encode(sampleResponse), 200);
      }
      return http.Response('Not Found', 404);
    });

    final service = PlacesService(client: mockClient);
    final results = await service.getAutocompleteSuggestions('Cairo');

    expect(results.length, equals(2));
    expect(results[0].placeId, equals('123456'));
    expect(results[0].description, equals('Cairo Tower, Cairo, Egypt'));
    expect(results[0].lat, equals(30.0459));
    expect(results[0].lng, equals(31.2243));

    final details = await service.getPlaceDetails('123456');
    expect(details.latitude, equals(30.0459));
    expect(details.longitude, equals(31.2243));
  });

  test('PlacesService reverse geocodes lat/lng into a friendly name', () async {
    final mockClient = MockClient((request) async {
      if (request.url.path == '/reverse') {
        final sampleResponse = {
          'name': 'Home Area',
          'display_name': 'Home Area, Cairo Governorate, Egypt',
        };
        return http.Response(json.encode(sampleResponse), 200);
      }
      return http.Response('Not Found', 404);
    });

    final service = PlacesService(client: mockClient);
    final label = await service.reverseGeocode(30.0444, 31.2357);

    expect(label, equals('Home Area'));
  });
}
