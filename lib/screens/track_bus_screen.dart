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
import 'dart:math';

const String googleApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

class TrackBusScreen extends StatefulWidget {
  final Map<String, dynamic>? booking; // Optional booking for direct tracking

  const TrackBusScreen({super.key, this.booking});

  @override
  _TrackBusScreenState createState() => _TrackBusScreenState();
}

class _TrackBusScreenState extends State<TrackBusScreen> {
  late Future<List<Map<String, dynamic>>> _busesFuture;
  bool _isLoading = true;

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
            buses.add({
              'bookingId': bookingDoc.id,
              'bookingData': bookingData,
              'busData': busData,
              'busId': busId,
            });
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
          title: Text('Track Bus'),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Track Your Buses'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
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
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Error loading buses: ${snapshot.error}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _busesFuture = _fetchCurrentBuses();
                      });
                    },
                    child: Text('Retry'),
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
                  Icon(Icons.directions_bus_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No active buses to track',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
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
            padding: EdgeInsets.all(16),
            itemCount: buses.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
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
                      leading: Icon(Icons.directions_bus,
                          color: Colors.blue, size: 32),
                      title: Text(
                        '${booking['destination'] ?? booking['route'] ?? ''}',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                      trailing: Icon(Icons.arrow_forward_ios, size: 18),
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
                          icon: Icon(Icons.location_searching),
                          label: Text('Track Bus'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
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
    _initializeTracking();
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
        Duration(seconds: 15), (_) => _fetchBusLocationAndRoute());
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

              // Only update if location has changed significantly
              if (busLocation == null ||
                  _getDistance(busLocation!, newBusLocation) > 0.01) {
                setState(() {
                  busLocation = newBusLocation;
                  connectionStatus = 'Live tracking active';
                });

                _updateRouteAndETA();
                _animateToShowBothLocations();
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

        final result = await _getRouteAndEta(busLocation!, passengerLocation!);

        setState(() {
          routePolyline = result['polyline'];
          etaMinutes = result['eta'];
          distanceKm = result['distance'];
          routeInfo = result['routeInfo'];
          isLoading = false;
        });
      } catch (e) {
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

  double _getDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // km
    final double lat1Rad = point1.latitude * (3.14159 / 180);
    final double lat2Rad = point2.latitude * (3.14159 / 180);
    final double deltaLat =
        (point2.latitude - point1.latitude) * (3.14159 / 180);
    final double deltaLng =
        (point2.longitude - point1.longitude) * (3.14159 / 180);
    final double a = pow(sin(deltaLat / 2), 2) +
        cos(lat1Rad) * cos(lat2Rad) * pow(sin(deltaLng / 2), 2);
    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _busLocationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Your Bus'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _fetchBusLocationAndRoute(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status and Info Card
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
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
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.booking['destination'] ?? 'Your Bus',
                            style: TextStyle(
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
                SizedBox(height: 16),
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
                      color: Colors.blue,
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
                ? Center(
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
                            Icon(Icons.location_off,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Bus or pickup location not available'),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _fetchBusLocationAndRoute(),
                              child: Text('Retry'),
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
                          zoom: 13,
                        ),
                        markers: {
                          Marker(
                            markerId: MarkerId('bus'),
                            position: busLocation!,
                            infoWindow: InfoWindow(
                              title: 'Your Bus',
                              snippet: 'Live location',
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueBlue),
                          ),
                          Marker(
                            markerId: MarkerId('pickup'),
                            position: passengerLocation!,
                            infoWindow: InfoWindow(
                              title: 'Pickup Location',
                              snippet: 'Your waiting point',
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueGreen),
                          ),
                        },
                        polylines: routePolyline.isNotEmpty
                            ? {
                                Polyline(
                                  polylineId: PolylineId('route'),
                                  points: routePolyline,
                                  color: Colors.blue,
                                  width: 4,
                                  patterns: [
                                    PatternItem.dash(20),
                                    PatternItem.gap(10)
                                  ],
                                ),
                              }
                            : {},
                        myLocationEnabled: false,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: false,
                      ),
          ),

          // Bottom info panel
          if (routeInfo.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Route Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    routeInfo,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
        ],
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
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getRouteAndEta(
      LatLng origin, LatLng destination) async {
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$googleApiKey&mode=driving&traffic_model=best_guess&departure_time=now';

    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final route = data['routes'][0];
        final leg = route['legs'][0];

        final encodedPolyline = route['overview_polyline']['points'];
        final duration = leg['duration']['value']; // in seconds
        final distance = leg['distance']['value']; // in meters
        final routeDescription =
            leg['start_address'] + ' to ' + leg['end_address'];

        List<LatLng> polylinePoints = _decodePolyline(encodedPolyline);

        return {
          'polyline': polylinePoints,
          'eta': (duration / 60).round(), // minutes
          'distance': distance / 1000.0, // kilometers
          'routeInfo': 'Via ${routeDescription}',
        };
      } else {
        throw Exception('No route found: ${data['status']}');
      }
    } catch (e) {
      print('Error fetching route: $e');
      throw Exception('Failed to fetch directions: $e');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return polyline;
  }
}
