import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:smart_bus_mobility_platform1/utils/google_api_key.dart';

class LiveBusDetailsSheet extends StatefulWidget {
  final String busId;
  final Map<String, dynamic> booking;
  final BitmapDescriptor? passengerIcon;
  const LiveBusDetailsSheet({
    required this.busId,
    required this.booking,
    this.passengerIcon,
    super.key,
  });

  @override
  State<LiveBusDetailsSheet> createState() => _LiveBusDetailsSheetState();
}

class _LiveBusDetailsSheetState extends State<LiveBusDetailsSheet> {
  LatLng? busLocation;
  LatLng? passengerLocation;
  List<LatLng> routePolyline = [];
  int etaMinutes = 0;
  bool isLoading = true;
  Timer? _timer;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _initializePassengerLocation();
    fetchBusLocationAndRoute();
    _timer = Timer.periodic(
        Duration(seconds: 10), (_) => fetchBusLocationAndRoute());
  }

  void _initializePassengerLocation() {
    try {
      final pickup = widget.booking['pickupLocation'];
      if (pickup != null) {
        if (pickup is Map<String, dynamic>) {
          final lat = pickup['latitude'];
          final lng = pickup['longitude'];
          if (lat != null && lng != null) {
            passengerLocation = LatLng(
              lat.toDouble(),
              lng.toDouble(),
            );
          }
        } else if (pickup is GeoPoint) {
          passengerLocation = LatLng(
            pickup.latitude,
            pickup.longitude,
          );
        }
      }
    } catch (e) {
      print('Error initializing passenger location: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> fetchBusLocationAndRoute() async {
    setState(() {
      isLoading = true;
    });
    try {
      final busId = widget.busId;
      if (busId.isEmpty) {
        throw Exception('Invalid bus ID');
      }

      final busDoc =
          await FirebaseFirestore.instance.collection('buses').doc(busId).get();

      if (busDoc.exists && busDoc.data() != null) {
        final busData = busDoc.data()!;
        final currentLocation = busData['currentLocation'];

        if (currentLocation != null) {
          if (currentLocation is Map<String, dynamic>) {
            final lat = currentLocation['latitude'];
            final lng = currentLocation['longitude'];
            if (lat != null && lng != null) {
              busLocation = LatLng(lat.toDouble(), lng.toDouble());
            }
          } else if (currentLocation is GeoPoint) {
            busLocation = LatLng(
              currentLocation.latitude,
              currentLocation.longitude,
            );
          }
        }
      }

      if (busLocation != null && passengerLocation != null) {
        try {
          final result = await getRouteAndEta(busLocation!, passengerLocation!);
          setState(() {
            routePolyline = result['polyline'];
            etaMinutes = result['eta'];
            isLoading = false;
          });
          _fitMapBounds();
        } catch (routeError) {
          print('Error fetching route: $routeError');
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bus location: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _fitMapBounds() {
    if (_mapController == null ||
        busLocation == null ||
        passengerLocation == null) return;

    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          math.min(busLocation!.latitude, passengerLocation!.latitude),
          math.min(busLocation!.longitude, passengerLocation!.longitude),
        ),
        northeast: LatLng(
          math.max(busLocation!.latitude, passengerLocation!.latitude),
          math.max(busLocation!.longitude, passengerLocation!.longitude),
        ),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50.0),
      );
    } catch (e) {
      print('Error fitting map bounds: $e');
    }
  }

  Future<Map<String, dynamic>> getRouteAndEta(
      LatLng origin, LatLng destination) async {
    try {
      // Check if API key is properly configured
      if (googleAPIKey.isEmpty) {
        // Fallback to simple distance calculation if API key is not configured
        return _calculateSimpleRoute(origin, destination);
      }

      final url =
          'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$googleAPIKey';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
            'HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }

      final data = json.decode(response.body);

      if (data['status'] == 'OK' &&
          data['routes'] != null &&
          data['routes'].isNotEmpty) {
        final route = data['routes'][0]['overview_polyline']['points'];
        final duration =
            data['routes'][0]['legs'][0]['duration']['value']; // in seconds
        List<LatLng> polylinePoints = decodePolyline(route);
        return {
          'polyline': polylinePoints,
          'eta': (duration / 60).round(),
        };
      } else {
        // Fallback to simple calculation if API fails
        return _calculateSimpleRoute(origin, destination);
      }
    } catch (e) {
      print('Error fetching route from Google API: $e');
      // Fallback to simple calculation
      return _calculateSimpleRoute(origin, destination);
    }
  }

  Map<String, dynamic> _calculateSimpleRoute(
      LatLng origin, LatLng destination) {
    // Simple straight-line route calculation as fallback
    List<LatLng> polyline = [origin, destination];

    // Calculate simple ETA based on distance
    double distance = _calculateDistance(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );

    // Assume 30 km/h average speed
    int etaMinutes = (distance / 30 * 60).round();

    return {
      'polyline': polyline,
      'eta': etaMinutes,
    };
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  List<LatLng> decodePolyline(String encoded) {
    try {
      if (encoded.isEmpty) {
        return [];
      }

      List<LatLng> polyline = [];
      int index = 0, len = encoded.length;
      int lat = 0, lng = 0;

      while (index < len) {
        int b, shift = 0, result = 0;

        // Decode latitude
        do {
          if (index >= len) break;
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);

        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        // Decode longitude
        shift = 0;
        result = 0;
        do {
          if (index >= len) break;
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);

        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        // Validate coordinates before adding
        final latitude = lat / 1E5;
        final longitude = lng / 1E5;

        if (latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180) {
          polyline.add(LatLng(latitude, longitude));
        }
      }

      return polyline;
    } catch (e) {
      print('Error decoding polyline: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    // Validate locations
    if (busLocation == null || passengerLocation == null) {
      return _buildErrorContent(
          'Live tracking unavailable: missing location data.');
    }

    // Validate coordinates
    if (busLocation!.latitude.isNaN ||
        busLocation!.longitude.isNaN ||
        passengerLocation!.latitude.isNaN ||
        passengerLocation!.longitude.isNaN) {
      return _buildErrorContent('Invalid location coordinates.');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(width: 12),
            const Text(
              'Live Bus Tracking',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Bus Plate: ${widget.booking['numberPlate'] ?? 'N/A'}'),
        Text('Departure: ${_formatDateTime(widget.booking['departureDate'])}'),
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
          child: Text(
            'ETA: $etaMinutes min',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          height: 220,
          margin: const EdgeInsets.only(top: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                _fitMapBounds();
              },
              initialCameraPosition: CameraPosition(
                target: busLocation!,
                zoom: 13,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('bus'),
                  position: busLocation!,
                  infoWindow: const InfoWindow(title: 'Bus Location'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                ),
                Marker(
                  markerId: const MarkerId('passenger'),
                  position: passengerLocation!,
                  infoWindow: const InfoWindow(title: 'Your Pickup Location'),
                  icon: widget.passengerIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen,
                      ),
                ),
              },
              polylines: routePolyline.isNotEmpty
                  ? {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: routePolyline,
                        color: Colors.blue,
                        width: 5,
                      ),
                    }
                  : {},
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: true,
              compassEnabled: true,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 16.0),
          child: Text(
            'Bus is moving from its current location to your pickup location.',
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.red[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic date) {
    try {
      if (date == null) {
        return 'Not specified';
      }

      if (date is Timestamp) {
        return DateFormat('MMM d, yyyy – HH:mm').format(date.toDate());
      } else if (date is DateTime) {
        return DateFormat('MMM d, yyyy – HH:mm').format(date);
      } else if (date is String) {
        // Try to parse the string as a date
        try {
          final parsedDate = DateTime.parse(date);
          return DateFormat('MMM d, yyyy – HH:mm').format(parsedDate);
        } catch (e) {
          // If parsing fails, return the string as is
          return date;
        }
      } else if (date is int) {
        // Handle timestamp as seconds or milliseconds
        try {
          final dateTime = DateTime.fromMillisecondsSinceEpoch(date);
          return DateFormat('MMM d, yyyy – HH:mm').format(dateTime);
        } catch (e) {
          return 'Invalid date';
        }
      }

      return 'Invalid date format';
    } catch (e) {
      print('Error formatting date: $e');
      return 'Date unavailable';
    }
  }
}



