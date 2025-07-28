import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:smart_bus_mobility_platform1/widgets/live_bus_details_sheet.dart';
import 'package:smart_bus_mobility_platform1/screens/track_bus_screen.dart';

class CurrentBusesScreen extends StatefulWidget {
  const CurrentBusesScreen({super.key});

  @override
  _CurrentBusesScreenState createState() => _CurrentBusesScreenState();
}

class _CurrentBusesScreenState extends State<CurrentBusesScreen> {
  late Stream<List<Map<String, dynamic>>> _currentBusesStream;
  bool _isLoading = true;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _initializeScreen() {
    // Show loading for exactly 2 seconds
    _loadingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    _currentBusesStream = _getCurrentBusesStream();
  }

  Stream<List<Map<String, dynamic>>> _getCurrentBusesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'confirmed')
        .snapshots()
        .asyncMap((bookingsSnapshot) async {
      List<Map<String, dynamic>> currentBuses = [];

      for (var bookingDoc in bookingsSnapshot.docs) {
        final bookingData = bookingDoc.data();
        final busId = bookingData['busId'];

        if (busId != null) {
          try {
            final busDoc = await FirebaseFirestore.instance
                .collection('buses')
                .doc(busId)
                .get();

            if (busDoc.exists) {
              final busData = busDoc.data()!;

              if (busData['status'] == 'active' ||
                  busData['currentLocation'] != null) {
                // Calculate ETA and add route information
                final enhancedBusInfo = await _enhanceBusInfo({
                  'bookingId': bookingDoc.id,
                  'bookingData': bookingData,
                  'busData': busData,
                  'busId': busId,
                });
                currentBuses.add(enhancedBusInfo);
              }
            }
          } catch (e) {
            print('Error fetching bus $busId: $e');
          }
        }
      }

      return currentBuses;
    });
  }

  Future<Map<String, dynamic>> _enhanceBusInfo(
      Map<String, dynamic> busInfo) async {
    final busData = busInfo['busData'];
    final bookingData = busInfo['bookingData'];

    // Get current location and pickup location
    final currentLocation = busData['currentLocation'];
    final pickupLocation = bookingData['pickupLocation'];

    // Prioritize ETA from booking data, which is updated periodically.
    if (bookingData['eta'] != null) {
      busInfo['eta'] = bookingData['eta'];
    } else if (currentLocation != null && pickupLocation != null) {
      // Fallback to manual calculation if ETA is not available in booking data.
      try {
        final eta = await _calculateETA(currentLocation, pickupLocation);
        busInfo['eta'] = eta;
      } catch (e) {
        print('Error calculating ETA fallback: $e');
        busInfo['eta'] = 'Calculating...';
      }
    } else {
      busInfo['eta'] = 'Location unavailable';
    }

    if (currentLocation != null && pickupLocation != null) {
      try {
        // Generate route polyline points with proper LatLng objects
        final routePoints =
            await _generateRoutePoints(currentLocation, pickupLocation);
        busInfo['routePoints'] = routePoints;

        // Convert LatLng objects to Map format for serialization
        busInfo['routePointsData'] = routePoints
            .map((point) => {
                  'latitude': point.latitude,
                  'longitude': point.longitude,
                })
            .toList();
      } catch (e) {
        print('Error enhancing bus info: $e');
        // Do not reset ETA, just handle route points error.
        busInfo['routePoints'] = <LatLng>[];
        busInfo['routePointsData'] = <Map<String, double>>[];
      }
    } else {
      busInfo['routePoints'] = <LatLng>[];
      busInfo['routePointsData'] = <Map<String, double>>[];
    }

    return busInfo;
  }

  Future<String> _calculateETA(Map<String, dynamic> currentLocation,
      Map<String, dynamic> pickupLocation) async {
    try {
      final double currentLat = currentLocation['latitude']?.toDouble() ?? 0.0;
      final double currentLng = currentLocation['longitude']?.toDouble() ?? 0.0;
      final double pickupLat = pickupLocation['latitude']?.toDouble() ?? 0.0;
      final double pickupLng = pickupLocation['longitude']?.toDouble() ?? 0.0;

      // Calculate straight-line distance using Haversine formula
      final double distance =
          _calculateDistance(currentLat, currentLng, pickupLat, pickupLng);

      // Estimate time based on average city speed (30 km/h) with traffic factor (1.5x)
      const double avgSpeedKmh = 30.0;
      const double trafficFactor = 1.5;
      final double estimatedTimeHours =
          (distance * trafficFactor) / avgSpeedKmh;
      final int estimatedMinutes = (estimatedTimeHours * 60).round();

      if (estimatedMinutes < 1) {
        return 'Arriving now';
      } else if (estimatedMinutes < 60) {
        return '$estimatedMinutes min';
      } else {
        final hours = estimatedMinutes ~/ 60;
        final remainingMinutes = estimatedMinutes % 60;
        return '${hours}h ${remainingMinutes}m';
      }
    } catch (e) {
      print('Error calculating ETA: $e');
      return 'Calculating...';
    }
  }

  double _calculateDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLng = _degreesToRadians(lng2 - lng1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  Future<List<LatLng>> _generateRoutePoints(
      Map<String, dynamic> start, Map<String, dynamic> end) async {
    try {
      final double startLat = start['latitude']?.toDouble() ?? 0.0;
      final double startLng = start['longitude']?.toDouble() ?? 0.0;
      final double endLat = end['latitude']?.toDouble() ?? 0.0;
      final double endLng = end['longitude']?.toDouble() ?? 0.0;

      // Validate coordinates - check for invalid or missing coordinates
      if (startLat == 0.0 ||
          startLng == 0.0 ||
          endLat == 0.0 ||
          endLng == 0.0 ||
          start['latitude'] == null ||
          start['longitude'] == null ||
          end['latitude'] == null ||
          end['longitude'] == null) {
        print(
            'Invalid coordinates detected: start($startLat, $startLng), end($endLat, $endLng)');
        return <LatLng>[];
      }

      List<LatLng> routePoints = [];

      // Add start point
      routePoints.add(LatLng(startLat, startLng));

      // Generate intermediate points for a more realistic route
      const int intermediatePoints = 10;
      for (int i = 1; i < intermediatePoints; i++) {
        final double ratio = i / intermediatePoints.toDouble();

        // Linear interpolation with slight curve to simulate road following
        final double lat = startLat + (endLat - startLat) * ratio;
        final double lng = startLng + (endLng - startLng) * ratio;

        // Add slight curve to make it look more like a real route
        // Use a more realistic curve that simulates following roads
        final double curveFactor =
            sin(ratio * pi) * 0.001; // Reduced curve for realism
        final double perpOffset =
            cos(ratio * 2 * pi) * 0.0005; // Small perpendicular offset

        routePoints.add(LatLng(lat + curveFactor, lng + perpOffset));
      }

      // Add end point
      routePoints.add(LatLng(endLat, endLng));

      return routePoints;
    } catch (e) {
      print('Error generating route points: $e');
      return <LatLng>[];
    }
  }

  void _navigateToBusTracking(Map<String, dynamic> busInfo) {
    try {
      final bookingData = busInfo['bookingData'];

      // Use the serialized route points data
      final routePointsData =
          busInfo['routePointsData'] as List<Map<String, dynamic>>? ??
              <Map<String, dynamic>>[];

      final enhancedBookingData = Map<String, dynamic>.from(bookingData);
      enhancedBookingData['routePoints'] = routePointsData;
      enhancedBookingData['busId'] = busInfo['busId'];
      enhancedBookingData['eta'] = busInfo['eta'];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TrackBusScreen(booking: enhancedBookingData),
        ),
      );
    } catch (e) {
      print('Error navigating to bus tracking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to track bus. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBusDetails(
      BuildContext context, Map<String, dynamic> busInfo) async {
    try {
      final booking = busInfo['bookingData'];
      final pickupLocation = booking['pickupLocation'];
      BitmapDescriptor? passengerIcon;

      if (pickupLocation != null) {
        try {
          passengerIcon = await MarkerIcons.passengerIcon;
        } catch (e) {
          print('Error loading passenger icon: $e');
        }
      }

      // Use the serialized route points data
      final routePointsData =
          busInfo['routePointsData'] as List<Map<String, dynamic>>? ??
              <Map<String, dynamic>>[];

      final enhancedBookingData = Map<String, dynamic>.from(booking);
      enhancedBookingData['routePoints'] = routePointsData;
      enhancedBookingData['eta'] = busInfo['eta'];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => LiveBusDetailsSheet(
          busId: busInfo['busId'],
          booking: enhancedBookingData,
          passengerIcon: passengerIcon,
        ),
      );
    } catch (e) {
      print('Error showing bus details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load bus details. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getBusStatus(Map<String, dynamic> busData) {
    final status = busData['status'];
    final currentLocation = busData['currentLocation'];

    if (status == 'active' && currentLocation != null) {
      return 'En Route';
    } else if (status == 'active') {
      return 'Active';
    } else if (currentLocation != null) {
      return 'Moving';
    } else {
      return 'Offline';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'en route':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'moving':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _refreshBuses() {
    setState(() {
      _isLoading = true;
      _currentBusesStream = _getCurrentBusesStream();
    });

    // Reset loading timer
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  // Handle back navigation properly
  Future<bool> _onWillPop() async {
    Navigator.pop(context);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Track Current Buses'),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshBuses,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading current buses...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please wait while we fetch your active bookings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            : StreamBuilder<List<Map<String, dynamic>>>(
                stream: _currentBusesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading current buses...'),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            'Error loading buses',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('${snapshot.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshBuses,
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
                          Icon(
                            Icons.location_searching,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No buses currently trackable',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your confirmed bookings with active buses will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.event_seat),
                            label: const Text('Book a Bus'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      _refreshBuses();
                      // Wait for the loading to complete
                      await Future.delayed(const Duration(seconds: 2));
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: buses.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final busInfo = buses[index];
                        final booking = busInfo['bookingData'];
                        final bus = busInfo['busData'];
                        final busStatus = _getBusStatus(bus);
                        final statusColor = _getStatusColor(busStatus);
                        final eta = busInfo['eta'] ?? 'Calculating...';

                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Stack(
                                  children: [
                                    Icon(
                                      Icons.directions_bus,
                                      color: Colors.blue[700],
                                      size: 32,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  '${booking['destination'] ?? booking['route'] ?? 'Unknown Route'}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: statusColor, width: 1),
                                          ),
                                          child: Text(
                                            busStatus,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.access_time,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          'ETA: $eta',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (booking['pickupLocation'] != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on,
                                              size: 14, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Pickup: ${booking['pickupAddress'] ?? 'Custom Location'}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600]),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (bus['numberPlate'] != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.confirmation_number,
                                              size: 14, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Plate: ${bus['numberPlate']}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    if (bus['driverName'] != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.person,
                                              size: 14, color: Colors.orange),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Driver: ${bus['driverName']}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 18),
                                onTap: () {
                                  _showBusDetails(context, busInfo);
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.info_outline,
                                            size: 18),
                                        label: const Text('Details'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.blue[700],
                                          side: BorderSide(
                                              color: Colors.blue[700]!),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          _showBusDetails(context, busInfo);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton.icon(
                                        icon: const Icon(
                                            Icons.location_searching,
                                            size: 18),
                                        label: const Text('Track Live'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: () {
                                          _navigateToBusTracking(busInfo);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}




