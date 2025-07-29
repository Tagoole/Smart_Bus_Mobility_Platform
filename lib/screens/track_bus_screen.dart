import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:smart_bus_mobility_platform1/widgets/live_bus_details_sheet.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

const String googleApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

class TrackBusScreen extends StatefulWidget {
  final Map<String, dynamic>? booking; // Optional booking for direct tracking

  const TrackBusScreen({super.key, this.booking});

  @override
  _TrackBusScreenState createState() => _TrackBusScreenState();
}

class _TrackBusScreenState extends State<TrackBusScreen> {
  late Future<List<Map<String, dynamic>>> _busesFuture;
  final bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // If a booking is provided, go directly to tracking that bus
    if (widget.booking != null) {
      _navigateToBusTracking(widget.booking!);
    } else {
      _busesFuture = _fetchCurrentBuses();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCurrentBuses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // Get user's active bookings
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'confirmed')
          .get();

      List<Map<String, dynamic>> buses = [];

      for (var bookingDoc in bookingsSnapshot.docs) {
        final bookingData = bookingDoc.data();
        final busId = bookingData['busId'];

        if (busId != null) {
          // Get bus details
          final busDoc = await FirebaseFirestore.instance
              .collection('buses')
              .doc(busId)
              .get();

          if (busDoc.exists) {
            final busData = busDoc.data()!;
            final enhancedBookingData = {
              'bookingId': bookingDoc.id,
              'bookingData': bookingData,
              'busData': busData,
              'busId': busId,
            };

            if (bookingData['routePoints'] != null) {
              final routePoints = bookingData['routePoints'] as List<LatLng>;
              enhancedBookingData['routePoints'] = routePoints
                  .map((point) => {
                        'latitude': point.latitude,
                        'longitude': point.longitude,
                      })
                  .toList();
            }

            buses.add(enhancedBookingData);
          }
        }
      }

      return buses;
    } catch (e) {
      print('Error fetching current buses: $e');
      return [];
    }
  }

  void _navigateToBusTracking(Map<String, dynamic> booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusTrackingDetailScreen(booking: booking),
      ),
    );
  }

  void _showBusDetails(BuildContext context, Map<String, dynamic> busInfo) {
    final booking = busInfo['bookingData'];
    final pickupLocation = booking['pickupLocation'];
    BitmapDescriptor? passengerIcon;

    if (pickupLocation != null) {
      MarkerIcons.passengerIcon.then((icon) {
        passengerIcon = icon;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => LiveBusDetailsSheet(
        busId: busInfo['busId'],
        booking: booking,
        passengerIcon: passengerIcon,
      ),
    );
  }

  String _formatDateTime(dynamic date) {
    if (date is Timestamp) {
      return DateFormat('MMM d, yyyy – HH:mm').format(date.toDate());
    } else if (date is DateTime) {
      return DateFormat('MMM d, yyyy – HH:mm').format(date);
    } else if (date is String) {
      return date;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    // If a booking was provided, show loading while navigating
    if (widget.booking != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Track Bus'),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Your Buses'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _busesFuture = _fetchCurrentBuses();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _busesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Error loading buses: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _busesFuture = _fetchCurrentBuses();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final buses = snapshot.data ?? [];

          if (buses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_bus_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No active buses to track',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You don\'t have any confirmed bookings at the moment',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: buses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final busInfo = buses[index];
              final booking = busInfo['bookingData'];
              final bus = busInfo['busData'];

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.directions_bus,
                          color: Colors.blue, size: 32),
                      title: Text(
                        '${booking['destination'] ?? booking['route'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Departure: ${_formatDateTime(booking['departureDate'])}'),
                          if (booking['pickupLocation'] != null)
                            Text(
                                'Pickup: (${booking['pickupLocation']['latitude']?.toStringAsFixed(5)}, ${booking['pickupLocation']['longitude']?.toStringAsFixed(5)})'),
                          Text('ETA: ${booking['eta'] ?? 'Calculating...'}'),
                          if (bus != null)
                            Text('Bus Plate: ${bus['numberPlate'] ?? 'N/A'}'),
                          if (bus != null && bus['driverName'] != null)
                            Text('Driver: ${bus['driverName']}'),
                          if (booking['totalFare'] != null)
                            Text('Fare: UGX ${booking['totalFare']}'),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                      onTap: () {
                        _showBusDetails(context, busInfo);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.location_searching),
                          label: const Text('Track Bus'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            _navigateToBusTracking(booking);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Separate screen for detailed bus tracking
class BusTrackingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const BusTrackingDetailScreen({super.key, required this.booking});

  @override
  _BusTrackingDetailScreenState createState() =>
      _BusTrackingDetailScreenState();
}

class _BusTrackingDetailScreenState extends State<BusTrackingDetailScreen> {
  LatLng? busLocation;
  LatLng? passengerLocation;
  GoogleMapController? mapController;

  List<LatLng> routePolyline = [];
  int etaMinutes = 0;
  double distanceKm = 0.0;
  String routeInfo = '';
  bool isLoading = true;
  String connectionStatus = 'Connecting...';

  Timer? _timer;
  StreamSubscription<DocumentSnapshot>? _busLocationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRoutePolylineFromBooking();
    _initializeTracking();
  }

  void _initializeRoutePolylineFromBooking() {
    final routePointsData = widget.booking['routePoints'] as List<dynamic>?;
    if (routePointsData != null && routePointsData.isNotEmpty) {
      routePolyline = routePointsData
          .map((point) => LatLng(point['latitude'], point['longitude']))
          .toList();
    }
  }

  void _initializeTracking() {
    // Extract pickup location from booking
    final pickup = widget.booking['pickupLocation'];
    if (pickup != null) {
      passengerLocation = LatLng(
        pickup['latitude']?.toDouble() ?? 0.0,
        pickup['longitude']?.toDouble() ?? 0.0,
      );
    }

    // Start real-time bus location tracking
    _startRealTimeTracking();

    // Fallback timer for additional updates
    _timer = Timer.periodic(
        const Duration(seconds: 15), (_) => _fetchBusLocationAndRoute());
  }

  void _startRealTimeTracking() {
    final busId = widget.booking['busId'];
    if (busId != null) {
      _busLocationSubscription = FirebaseFirestore.instance
          .collection('buses')
          .doc(busId)
          .snapshots()
          .listen(
        (DocumentSnapshot snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data() as Map<String, dynamic>;
            final location = data['currentLocation'];

            if (location != null) {
              final newBusLocation = LatLng(
                location['latitude']?.toDouble() ?? 0.0,
                location['longitude']?.toDouble() ?? 0.0,
              );

              setState(() {
                busLocation = newBusLocation;
                connectionStatus = 'Live tracking active';
              });

              // Calculate route whenever bus location updates
              if (passengerLocation != null) {
                _calculateAndDrawRoute(busLocation!, passengerLocation!);
              }
            }
          }
        },
        onError: (error) {
          setState(() {
            connectionStatus = 'Connection error';
          });
        },
      );
    }
  }

  Future<void> _fetchBusLocationAndRoute() async {
    if (_busLocationSubscription != null) return; // Skip if real-time is active

    try {
      final busId = widget.booking['busId'];
      final busDoc =
          await FirebaseFirestore.instance.collection('buses').doc(busId).get();

      if (busDoc.exists && busDoc.data() != null) {
        final loc = busDoc.data()!['currentLocation'];
        if (loc != null) {
          setState(() {
            busLocation = LatLng(
              loc['latitude']?.toDouble() ?? 0.0,
              loc['longitude']?.toDouble() ?? 0.0,
            );
            connectionStatus = 'Updated';
          });

          _updateRouteAndETA();
        }
      }
    } catch (e) {
      setState(() {
        connectionStatus = 'Update failed';
        isLoading = false;
      });
    }
  }

  Future<void> _updateRouteAndETA() async {
    if (busLocation != null && passengerLocation != null) {
      try {
        setState(() {
          isLoading = true;
        });

        // Get route from Google Directions API
        final url = 'https://maps.googleapis.com/maps/api/directions/json'
            '?origin=${busLocation!.latitude},${busLocation!.longitude}'
            '&destination=${passengerLocation!.latitude},${passengerLocation!.longitude}'
            '&mode=driving'
            '&key=$googleApiKey';

        final response = await http.get(Uri.parse(url));
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          // Extract route points from response
          final points = data['routes'][0]['overview_polyline']['points'];
          final duration = data['routes'][0]['legs'][0]['duration']['value'];
          final distance = data['routes'][0]['legs'][0]['distance']['value'];

          // Decode polyline points
          final polylinePoints = PolylinePoints()
              .decodePolyline(points)
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          setState(() {
            routePolyline = polylinePoints;
            etaMinutes = (duration / 60).round();
            distanceKm = distance / 1000;
            isLoading = false;
          });

          // Animate camera to show both locations
          _animateToShowBothLocations();
        }
      } catch (e) {
        print('Error updating route: $e');
        setState(() {
          isLoading = false;
          connectionStatus = 'Route calculation failed';
        });
      }
    }
  }

  void _animateToShowBothLocations() {
    if (mapController != null &&
        busLocation != null &&
        passengerLocation != null) {
      // Calculate bounds to show both locations
      final southwest = LatLng(
        busLocation!.latitude < passengerLocation!.latitude
            ? busLocation!.latitude
            : passengerLocation!.latitude,
        busLocation!.longitude < passengerLocation!.longitude
            ? busLocation!.longitude
            : passengerLocation!.longitude,
      );

      final northeast = LatLng(
        busLocation!.latitude > passengerLocation!.latitude
            ? busLocation!.latitude
            : passengerLocation!.latitude,
        busLocation!.longitude > passengerLocation!.longitude
            ? busLocation!.longitude
            : passengerLocation!.longitude,
      );

      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: southwest, northeast: northeast),
          100.0, // padding
        ),
      );
    }
  }

  int _parseEta(String eta) {
    if (eta.contains('min')) {
      return int.tryParse(eta.replaceAll(' min', '')) ?? 0;
    } else if (eta.contains('h')) {
      final parts = eta.split('h ');
      final hours = int.tryParse(parts[0]) ?? 0;
      final minutes = int.tryParse(parts[1].replaceAll('m', '')) ?? 0;
      return (hours * 60) + minutes;
    }
    return 0;
  }

  double _getDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // km
    final double lat1Rad = point1.latitude * (3.14159 / 180);
    final double lat2Rad = point2.latitude * (3.14159 / 180);
    final double deltaLat =
        (point2.latitude - point1.latitude) * (3.14159 / 180);
    final double deltaLng =
        (point2.longitude - point1.longitude) * (3.14159 / 180);
    final double a = math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.pow(math.sin(deltaLng / 2), 2);
    final double c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  Future<void> _calculateAndDrawRoute(LatLng start, LatLng end) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${start.latitude},${start.longitude}'
          '&destination=${end.latitude},${end.longitude}'
          '&mode=driving'
          '&key=$googleApiKey';

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final points = data['routes'][0]['overview_polyline']['points'];
        final duration = data['routes'][0]['legs'][0]['duration']['value'];
        final distance = data['routes'][0]['legs'][0]['distance']['value'];

        final polylinePoints = PolylinePoints()
            .decodePolyline(points)
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
        // Prioritize the ETA from the booking data, which is updated periodically.
        final bookingETA = widget.booking['eta'];
        final calculatedEtaMinutes = (duration / 60).round();
        setState(() {
          routePolyline = polylinePoints;
          // Use booking ETA if available, otherwise use calculated ETA.
          etaMinutes =
              bookingETA != null ? _parseEta(bookingETA) : calculatedEtaMinutes;
          distanceKm = distance / 1000;
          isLoading = false;
        });

        // Animate map to show the entire route
        if (mapController != null) {
          final bounds = LatLngBounds(
            southwest: LatLng(
              math.min(start.latitude, end.latitude),
              math.min(start.longitude, end.longitude),
            ),
            northeast: LatLng(
              math.max(start.latitude, end.latitude),
              math.max(start.longitude, end.longitude),
            ),
          );

          mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 100),
          );
        }
      }
    } catch (e) {
      print('Error calculating route: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _busLocationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Pop until we reach the home screen
        Navigator.of(context).popUntil((route) => route.isFirst);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Track Your Bus'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Pop until we reach the home screen
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetchBusLocationAndRoute(),
            ),
          ],
        ),
        body: Column(
          children: [
            // Status and Info Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_bus,
                          color: Colors.blue[700], size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.booking['destination'] ?? 'Your Bus',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              connectionStatus,
                              style: TextStyle(
                                color: connectionStatus.contains('Live')
                                    ? Colors.green
                                    : connectionStatus.contains('error')
                                        ? Colors.red
                                        : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoTile(
                        icon: Icons.access_time,
                        label: 'ETA',
                        value: isLoading ? '...' : '$etaMinutes min',
                        color: Colors.green,
                      ),
                      _buildInfoTile(
                        icon: Icons.route,
                        label: 'Distance',
                        value: isLoading
                            ? '...'
                            : '${distanceKm.toStringAsFixed(1)} km',
                        color: Colors.green,
                      ),
                      _buildInfoTile(
                        icon: Icons.speed,
                        label: 'Status',
                        value: busLocation != null ? 'En Route' : 'Locating...',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: isLoading && busLocation == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Locating your bus...'),
                        ],
                      ),
                    )
                  : (busLocation == null || passengerLocation == null)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_off,
                                  size: 48, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('Bus or pickup location not available'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => _fetchBusLocationAndRoute(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : GoogleMap(
                          onMapCreated: (GoogleMapController controller) {
                            mapController = controller;
                            _animateToShowBothLocations();
                          },
                          initialCameraPosition: CameraPosition(
                            target: busLocation!,
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('bus'),
                              position: busLocation!,
                              infoWindow: const InfoWindow(
                                title: 'Your Bus',
                                snippet: 'Live location',
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueBlue),
                            ),
                            Marker(
                              markerId: const MarkerId('pickup'),
                              position: passengerLocation!,
                              infoWindow: const InfoWindow(
                                title: 'Pickup Location',
                                snippet: 'Your waiting point',
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueGreen),
                            ),
                          },
                          polylines: {
                            if (routePolyline.isNotEmpty)
                              Polyline(
                                polylineId: const PolylineId('route'),
                                points: routePolyline,
                                color: Colors.blue,
                                width: 4,
                                patterns: [
                                  PatternItem.dash(20),
                                  PatternItem.gap(10)
                                ],
                              ),
                          },
                          myLocationEnabled: false,
                          zoomControlsEnabled: true,
                          mapToolbarEnabled: true,
                          compassEnabled: true,
                          myLocationButtonEnabled: true,
                        ),
            ),

            // Bottom info panel
            if (routeInfo.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Route Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      routeInfo,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}












