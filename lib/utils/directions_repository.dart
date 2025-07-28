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
    List<LatLng>? waypoints,
  }) async {
    // Build waypoints string if provided
    String? waypointsStr;
    if (waypoints != null && waypoints.isNotEmpty) {
      // Force order with optimize:false|
      waypointsStr = 'optimize:false|' + waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|');
      print('[DEBUG] Directions API waypoints: $waypointsStr');
    }
    final response = await _dio.get(
      _baseUrl,
      queryParameters: {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'walking',
        if (waypointsStr != null) 'waypoints': waypointsStr,
        'key': googleAPIKey,
      },
    );
    if (response.statusCode == 200) {
      return Directions.fromMap(response.data);
    }
    return null;
  }
}










