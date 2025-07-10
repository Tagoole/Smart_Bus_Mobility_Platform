import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_model.dart';
import 'package:smart_bus_mobility_platform1/utils/google_api_key.dart'; // Store your API key here

/// Repository for fetching directions and route polylines from Google Directions API.
class DirectionsRepository {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json?';

  final Dio _dio;

  DirectionsRepository({Dio? dio}) : _dio = dio ?? Dio();

  /// Fetches directions between [origin] and [destination].
  /// Returns a [Directions] object with polyline points, bounds, distance, and duration.
  Future<Directions?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await _dio.get(
      _baseUrl,
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': googleAPIKey, // Import your API key from a safe location
      },
    );

    // Check if response is successful
    if (response.statusCode == 200) {
      return Directions.fromMap(response.data);
    }
    return null;
  }
}
