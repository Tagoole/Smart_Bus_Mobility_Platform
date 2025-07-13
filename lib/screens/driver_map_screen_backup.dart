/*import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:smart_bus_mobility_platform1/resources/bus_service.dart';
import 'package:smart_bus_mobility_platform1/resources/map_service.dart' as som;
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;
  static final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(
      0.34540783865964797,
      32.54297125499706,
    ), // Kampala coordinates
    zoom: 14,
  );

  // Services
  final BusService _busService = BusService();

  // Driver data
  String? _driverId;
  String _driverName = 'Driver';
  String _driverEmail = '';
  BusModel? _driverBus;

  // Location tracking
  LatLng? _driverLocation;
  BitmapDescriptor? _driverMarkerIcon;
  BitmapDescriptor? _passengerMarkerIcon;
  final Map<String, BitmapDescriptor> _passengerIconCache = {};
  bool _isLoadingLocation = false;
  bool _isOnline = false;

  // Passengers data
  List<Map<String, dynamic>> _passengers = [];
  final Set<Marker> _allMarkers = {};
  bool _isLoadingRoute = false;

  // UI state
  bool _isLoading = true;
  String _statusMessage = 'Loading...';

  // Route summary data
  bool _showRouteSummary = false;
  final Set<Polyline> _allPolylines = {}; // Add this for multiple polylines

  // Timer for passenger data refresh
  Timer? _passengerRefreshTimer;

  // Animation for flowing route effect
  Timer? _flowingAnimationTimer;
  double _flowingAnimationOffset = 0.0;
  bool _isAnimating = false;

  Future<void> _loadMarkerIcons() async {
    try {
      // Load driver marker icon (bus icon) - fixed size
      _driverMarkerIcon = await MarkerIcons.busIcon;

      // Load passenger marker icon - fixed size
      _passengerMarkerIcon = await MarkerIcons.passengerIcon;
    } catch (e) {
      print('Error loading marker icons: $e');
      // Fallback to default markers if custom icons fail
      _driverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      );
      _passengerMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
    }
  }

  // Get current user ID
  String? _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // Load driver data and associated bus
  Future<void> _loadDriverData() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        setState(() {
          _statusMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      _driverId = userId;

      // Get driver user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _driverName = userData['name'] ?? userData['username'] ?? 'Driver';
          _driverEmail = userData['email'] ?? '';
        });
      }

      // Find the bus assigned to this driver
      final busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driverId', isEqualTo: _driverEmail)
          .where('isAvailable', isEqualTo: true)
          .limit(1)
          .get();

      if (busSnapshot.docs.isNotEmpty) {
        final busData = busSnapshot.docs.first.data();
        setState(() {
          _driverBus = BusModel.fromJson(busData, busSnapshot.docs.first.id);
        });

        // Load passengers for this bus
        await _loadPassengers();
      } else {
        print('No bus assigned to driver: $_driverEmail');
        setState(() {
          _statusMessage = 'No bus assigned to you';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading driver data: $e');
      setState(() {
        _statusMessage = 'Error loading driver data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Load passengers who have booked this driver's bus
  Future<void> _loadPassengers() async {
    if (_driverBus == null) {
      print('No driver bus available for loading passengers');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('busId', isEqualTo: _driverBus!.busId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      final List<Map<String, dynamic>> passengers = [];

      for (var doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();

        // Get user data for each booking
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(bookingData['userId'])
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          passengers.add({
            'bookingId': doc.id,
            'userId': bookingData['userId'],
            'userName': userData['name'] ?? userData['username'] ?? 'Passenger',
            'userEmail': userData['email'] ?? '',
            'pickupLocation': bookingData['pickupLocation'],
            'pickupAddress': bookingData['pickupAddress'] ?? 'Unknown location',
            'selectedSeats': bookingData['selectedSeats'] ?? [],
            'totalFare': bookingData['totalFare'] ?? 0.0,
            'departureDate': bookingData['departureDate'],
            'adultCount': bookingData['adultCount'] ?? 1,
            'childrenCount': bookingData['childrenCount'] ?? 0,
            'role': userData['role'], // Add role to passenger data
          });
        }
      }

      setState(() {
        _passengers = passengers;
        _isLoading = false;
      });

      _updateMarkers();
      await _drawOptimalRouteSOM();
    } catch (e) {
      print('Error loading passengers: $e');
      setState(() {
        _statusMessage = 'Error loading passengers: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Web-specific location permission check
  Future<bool> _checkWebLocationPermission() async {
    if (kIsWeb) {
      try {
        // For web, we'll try to get a position with a very short timeout
        // to check if permission is granted
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 3),
        );
        return true;
      } catch (e) {
        print('Web location permission check failed: $e');
        return false;
      }
    }
    return true;
  }

  // Get driver's current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        _showSnackBar(
          'Location services are disabled. Please enable location services.',
        );
        // Use default location and continue
        _setDefaultLocation();
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          _showSnackBar('Location permissions are denied.');
          // Use default location and continue
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        _showSnackBar('Location permissions are permanently denied.');
        // Use default location and continue
        _setDefaultLocation();
        return;
      }

      // Additional web-specific permission check
      if (kIsWeb) {
        bool webPermissionGranted = await _checkWebLocationPermission();
        if (!webPermissionGranted) {
          _showSnackBar(
            'Please allow location access in your browser settings and try again.',
          );
          _setDefaultLocation();
          return;
        }
      }

      // Try to get current position with different strategies
      Position? position;

      try {
        // First try: High accuracy with timeout
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        );
      } catch (e) {
        print('High accuracy location failed, trying medium accuracy: $e');

        try {
          // Second try: Medium accuracy with longer timeout
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          );
        } catch (e) {
          print('Medium accuracy location failed, trying low accuracy: $e');

          try {
            // Third try: Low accuracy with longest timeout
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 20),
            );
          } catch (e) {
            print('All location attempts failed: $e');

            // Fallback: Use last known position if available
            try {
              position = await Geolocator.getLastKnownPosition();
              if (position != null) {
                print('Using last known position as fallback');
              } else {
                throw Exception('No last known position available');
              }
            } catch (e) {
              print('Last known position also failed: $e');
              // Use default location as final fallback
              _setDefaultLocation();
              return;
            }
          }
        }
      }

      // Successfully got location
      setState(() {
        _driverLocation = LatLng(position!.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Update camera to driver location
      if (_controller.isCompleted) {
        GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _driverLocation!, zoom: 15),
          ),
        );
      }

      _updateMarkers();
      _updateDriverLocationInFirestore();
      await _drawOptimalRouteSOM();

      print(
        'Location updated successfully: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      print('Error getting location: $e');

      // Show appropriate error message
      String errorMessage = 'Error getting your location. ';
      if (e.toString().contains('Position update is unavailable')) {
        errorMessage +=
            'Please check your browser location settings and try again. For web browsers, make sure to allow location access when prompted.';
      } else if (e.toString().contains('timeout')) {
        errorMessage += 'Location request timed out. Please try again.';
      } else {
        errorMessage += 'Please try again.';
      }

      _showSnackBar(errorMessage);

      // Always set default location as fallback
      _setDefaultLocation();
    }
  }

  // Helper method to set default location
  void _setDefaultLocation() {
    setState(() {
      _driverLocation = LatLng(0.34540783865964797, 32.54297125499706);
      _isLoadingLocation = false;
    });

    // Update camera to default location
    if (_controller.isCompleted) {
      _controller.future.then((controller) {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(0.34540783865964797, 32.54297125499706),
              zoom: 15,
            ),
          ),
        );
      });
    }

    _updateMarkers();
    _updateDriverLocationInFirestore();
    _drawOptimalRouteSOM();
  }

  // Update driver location in Firestore
  Future<void> _updateDriverLocationInFirestore() async {
    if (_driverLocation == null || _driverId == null) return;

    try {
      // Update driver location in users collection (where the driver document already exists)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_driverId)
          .update({
            'currentLocation': {
              'latitude': _driverLocation!.latitude,
              'longitude': _driverLocation!.longitude,
            },
            'isOnline': _isOnline,
            'lastUpdated': FieldValue.serverTimestamp(),
            'assignedBusId': _driverBus?.busId,
            'assignedBusPlate': _driverBus?.numberPlate,
          });

      print('Driver location updated successfully for driver: $_driverId');

      // Also update bus location if driver has an assigned bus
      if (_driverBus != null) {
        try {
          await _busService.updateBusLocation(
            _driverBus!.busId,
            _driverLocation!.latitude,
            _driverLocation!.longitude,
          );
          print(
            'Bus location updated successfully for bus: ${_driverBus!.busId}',
          );
        } catch (busError) {
          print('Error updating bus location: $busError');
        }
      }
    } catch (e) {
      print('Error updating driver location: $e');
      // If update fails, try to set the document with merge option
      try {
        await FirebaseFirestore.instance.collection('users').doc(_driverId).set(
          {
            'currentLocation': {
              'latitude': _driverLocation!.latitude,
              'longitude': _driverLocation!.longitude,
            },
            'isOnline': _isOnline,
            'lastUpdated': FieldValue.serverTimestamp(),
            'assignedBusId': _driverBus?.busId,
            'assignedBusPlate': _driverBus?.numberPlate,
          },
          SetOptions(merge: true),
        );
        print('Driver location set successfully with merge option');
      } catch (setError) {
        print('Error setting driver location: $setError');
      }
    }
  }

  // Update all markers on the map
  Future<void> _updateMarkers() async {
    _allMarkers.clear();

    // Add driver location marker
    if (_driverLocation != null && _driverMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('driver_location'),
          position: _driverLocation!,
          icon: _driverMarkerIcon!, // Always set by MarkerIcons.busIcon
          anchor: Offset(0.5, 0.5),
          flat: true,
          infoWindow: InfoWindow(
            title: 'Your Location (START)',
            snippet: 'Driver:  _driverName',
          ),
        ),
      );
    }

    // Add passenger markers with labeled icons - multiple icons based on passenger count
    for (int i = 0; i < _passengers.length; i++) {
      final passenger = _passengers[i];
      if (passenger['pickupLocation'] != null) {
        final location = passenger['pickupLocation'];
        final latLng = LatLng(location['latitude'], location['longitude']);
        final userName = passenger['userName'] ?? 'Passenger';
        final adultCount = passenger['adultCount'] ?? 1;
        final childrenCount = passenger['childrenCount'] ?? 0;
        final totalPassengers = adultCount + childrenCount;

        // Create multiple markers based on total passenger count
        for (int j = 0; j < totalPassengers; j++) {
          // Use icon-only passenger marker
          final icon = await MarkerIcons.passengerIcon;

          // Slightly offset each marker to avoid overlap
          final offset = j * 0.0001; // Small offset in degrees
          final offsetLatLng = LatLng(
            latLng.latitude + offset,
            latLng.longitude + offset,
          );

          _allMarkers.add(
            Marker(
              markerId: MarkerId('passenger_${passenger['userId']}_$j'),
              position: offsetLatLng,
              icon: icon,
              anchor: Offset(0.5, 0.5),
              flat: true,
              infoWindow: InfoWindow(
                title:
                    'Passenger ${i + 1}: $userName (${j + 1}/$totalPassengers)',
                snippet:
                    '${passenger['selectedSeats'].length} seats • ${passenger['pickupAddress']}',
              ),
              onTap: () => _showPassengerDetails(passenger),
            ),
          );
        }
      }
    }
    setState(() {});
  }

  // Show passenger details dialog
  void _showPassengerDetails(Map<String, dynamic> passenger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Passenger Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${passenger['userName']}'),
            SizedBox(height: 8),
            Text('Email: ${passenger['userEmail']}'),
            SizedBox(height: 8),
            Text('Pickup: ${passenger['pickupAddress']}'),
            SizedBox(height: 8),
            Text('Seats: ${passenger['selectedSeats'].join(', ')}'),
            SizedBox(height: 8),
            Text(
              'Passengers: ${passenger['adultCount']} Adults, ${passenger['childrenCount']} Children',
            ),
            SizedBox(height: 8),
            Text(
              'Total Fare: UGX ${passenger['totalFare'].toStringAsFixed(0)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToPassenger(passenger);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Navigate'),
          ),
        ],
      ),
    );
  }

  // Update _navigateToPassenger to draw the polyline
  void _navigateToPassenger(Map<String, dynamic> passenger) async {
    if (passenger['pickupLocation'] != null && _driverLocation != null) {
      final location = passenger['pickupLocation'];
      final LatLng passengerLatLng = LatLng(
        location['latitude'],
        location['longitude'],
      );

      // Move camera
      if (_controller.isCompleted) {
        _controller.future.then((controller) {
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: passengerLatLng, zoom: 16),
            ),
          );
        });
      }

      _showSnackBar('Navigating to ${passenger['userName']}');
    }
  }

  // Toggle online status
  void _toggleOnlineStatus() {
    setState(() {
      _isOnline = !_isOnline;
    });
    _updateDriverLocationInFirestore();
    _showSnackBar(_isOnline ? 'You are now online' : 'You are now offline');
  }

  // Refresh data
  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Refreshing...';
    });

    try {
      await _loadDriverData();
      // Location updates are manual only - use the location refresh button

      setState(() {
        _isLoading = false;
        _statusMessage = 'Data refreshed (location manual)';
      });

      // Clear status message after a short delay
      Timer(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _statusMessage = '';
          });
        }
      });
    } catch (e) {
      print('Error during refresh: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Refresh failed: ${e.toString()}';
      });
    }
  }

  // Show snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Start flowing animation
  void _startFlowingAnimation() {
    if (_isAnimating || !mounted || _allPolylines.isEmpty) return;

    _isAnimating = true;
    _flowingAnimationTimer = Timer.periodic(Duration(milliseconds: 100), (
      timer,
    ) {
      if (mounted && _allPolylines.isNotEmpty) {
        setState(() {
          _flowingAnimationOffset += 0.02;
          if (_flowingAnimationOffset > 1.0) {
            _flowingAnimationOffset = 0.0;
          }
        });
      } else {
        _stopFlowingAnimation();
      }
    });
  }

  // Stop flowing animation
  void _stopFlowingAnimation() {
    _isAnimating = false;
    _flowingAnimationTimer?.cancel();
    _flowingAnimationTimer = null;
  }

  // Get actual road route between two points (instead of straight line)
  Future<List<LatLng>> _getRoadRoute(LatLng start, LatLng end) async {
    try {
      final directions = await DirectionsRepository().getDirections(
        origin: start,
        destination: end,
      );

      if (directions != null && directions.polylinePoints.isNotEmpty) {
        return directions.polylinePoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
      }
    } catch (e) {
      print('Error getting road route: $e');
    }

    // Fallback to straight line if directions fail
    return [start, end];
  }

  // Enhanced flowing route visualization - like a river flowing through different sections
  Future<void> _drawOptimalRouteSOM() async {
    if (_driverLocation == null || _passengers.isEmpty) return;

    // Gather all stops: bus (driver) first, then all passengers
    List<som.BusStop> stops = [
      som.BusStop(
        id: 'bus',
        location: som.LatLng(
          _driverLocation!.latitude,
          _driverLocation!.longitude,
        ),
        name: 'Bus',
      ),
      ..._passengers.map(
        (p) => som.BusStop(
          id: p['userId'],
          location: som.LatLng(
            p['pickupLocation']['latitude'],
            p['pickupLocation']['longitude'],
          ),
          name: p['userName'],
        ),
      ),
    ];

    final somRoute = som.BusRouteSOM(
      coordinates: stops.map((s) => s.location).toList(),
    );
    final optimizedRoute = await somRoute.optimizeRoute(stops);

    // Convert som.LatLng to google_maps_flutter LatLng for map display
    final List<LatLng> routeCoords = optimizedRoute.routeCoordinates
        .map((c) => LatLng(c.latitude, c.longitude))
        .toList();

    // Calculate total distance
    double totalDistance = 0.0;
    for (int i = 0; i < routeCoords.length - 1; i++) {
      totalDistance += _calculateDistance(routeCoords[i], routeCoords[i + 1]);
    }

    // Update markers with route order labels
    _updateMarkersWithRouteOrder(optimizedRoute.orderedStops);

    // Create flowing route visualization
    _allPolylines.clear();

    // Draw the main bus route (from start to destination) if bus data is available
    if (_driverBus != null) {
      try {
        final initialRoute = await _getInitialBusRoute();
        if (initialRoute.isNotEmpty) {
          _allPolylines.add(
            Polyline(
              polylineId: PolylineId('main_bus_route'),
              points: initialRoute,
              color: Colors.blue.withValues(alpha: 0.6),
              width: 8,
              geodesic: true,
            ),
          );
        }
      } catch (e) {
        print('Error drawing main bus route: $e');
      }
    }

    // Create flowing route segments with river-like colors
    final List<Color> flowingColors = [
      Colors.blue.shade900, // Deep blue (source)
      Colors.blue.shade700, // River blue
      Colors.cyan.shade600, // Cyan
      Colors.teal.shade500, // Teal
      Colors.green.shade400, // Green
      Colors.lime.shade400, // Lime
      Colors.yellow.shade400, // Yellow
      Colors.orange.shade400, // Orange
      Colors.red.shade400, // Red
      Colors.purple.shade400, // Purple
    ];

    // Draw the optimized pickup route with flowing colors
    for (int i = 0; i < routeCoords.length - 1; i++) {
      final colorIndex = i % flowingColors.length;
      final currentColor = flowingColors[colorIndex];

      // Create animated flowing effect
      final animatedOffset = (_flowingAnimationOffset + (i * 0.1)) % 1.0;
      final animatedOpacity =
          0.6 + (0.4 * (0.5 + 0.5 * sin(animatedOffset * 2 * pi)));

      // Create a gradient effect by varying opacity
      final baseOpacity = 0.7 + (0.3 * (i / (routeCoords.length - 1)));
      final finalOpacity = baseOpacity * animatedOpacity;

      // Get actual road route instead of straight line
      final roadRoute = await _getRoadRoute(routeCoords[i], routeCoords[i + 1]);

      _allPolylines.add(
        Polyline(
          polylineId: PolylineId('flowing_route_$i'),
          points: roadRoute,
          color: currentColor.withValues(alpha: finalOpacity),
          width: 6,
          geodesic: false, // Use actual road route
        ),
      );
    }

    // Add animated flowing dots along the route
    if (routeCoords.length > 1) {
      final animatedDotPosition =
          (_flowingAnimationOffset * (routeCoords.length - 1)).floor();
      if (animatedDotPosition < routeCoords.length - 1) {
        final startPoint = routeCoords[animatedDotPosition];
        final endPoint = routeCoords[animatedDotPosition + 1];
        final progress =
            (_flowingAnimationOffset * (routeCoords.length - 1)) % 1.0;

        // Interpolate between start and end points
        final animatedPoint = LatLng(
          startPoint.latitude +
              (endPoint.latitude - startPoint.latitude) * progress,
          startPoint.longitude +
              (endPoint.longitude - startPoint.longitude) * progress,
        );

        _allPolylines.add(
          Polyline(
            polylineId: PolylineId('flowing_dot'),
            points: [
              animatedPoint,
              animatedPoint,
            ], // Single point as a small line
            color: Colors.white,
            width: 8,
            geodesic: true,
          ),
        );
      }
    }

    // Add a main flowing route line that connects all points
    _allPolylines.add(
      Polyline(
        polylineId: PolylineId('flowing_main_route'),
        points: routeCoords,
        color: Colors.blue.shade600.withValues(alpha: 0.8),
        width: 4,
        geodesic: true,
      ),
    );

    // Add destination route if we have bus destination coordinates
    if (_driverBus != null &&
        _driverBus!.destinationLat != null &&
        _driverBus!.destinationLng != null) {
      final destinationPoint = LatLng(
        _driverBus!.destinationLat!,
        _driverBus!.destinationLng!,
      );

      // Connect the last passenger pickup to the final destination
      if (routeCoords.isNotEmpty) {
        final finalRoadRoute = await _getRoadRoute(
          routeCoords.last,
          destinationPoint,
        );
        _allPolylines.add(
          Polyline(
            polylineId: PolylineId('final_destination_route'),
            points: finalRoadRoute,
            color: Colors.red.shade600,
            width: 8,
            geodesic: false, // Use actual road route
          ),
        );
      }
    }

    setState(() {});

    // Start the flowing animation
    _startFlowingAnimation();

    // Show route summary
    _displayRouteSummary(totalDistance, optimizedRoute.orderedStops);
  }

  // Get initial bus route coordinates (from start to destination)
  Future<List<LatLng>> _getInitialBusRoute() async {
    if (_driverBus == null) return [];

    try {
      // Get coordinates for start and destination points
      final startCoords = await _getCoordinatesForAddress(
        _driverBus!.startPoint,
      );
      final destCoords = await _getCoordinatesForAddress(
        _driverBus!.destination,
      );

      if (startCoords != null && destCoords != null) {
        // Get route between start and destination
        final directions = await DirectionsRepository().getDirections(
          origin: startCoords,
          destination: destCoords,
        );

        if (directions != null && directions.polylinePoints.isNotEmpty) {
          return directions.polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        }
      }

      // Fallback: return direct line between start and destination
      if (startCoords != null && destCoords != null) {
        return [startCoords, destCoords];
      }
    } catch (e) {
      print('Error getting initial bus route: $e');
    }

    return [];
  }

  // Helper method to get coordinates for an address
  Future<LatLng?> _getCoordinatesForAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      print('Error getting coordinates for address $address: $e');
    }
    return null;
  }

  // Calculate distance between two points in kilometers
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double lat1 = start.latitude * (pi / 180);
    final double lat2 = end.latitude * (pi / 180);
    final double deltaLat = (end.latitude - start.latitude) * (pi / 180);
    final double deltaLng = (end.longitude - start.longitude) * (pi / 180);

    final double a =
        sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  // Update markers with route order labels
  void _updateMarkersWithRouteOrder(List<som.BusStop> routeStops) {
    _allMarkers.clear();

    // Add driver location marker (bus icon)
    if (_driverLocation != null && _driverMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('driver_location'),
          position: _driverLocation!,
          icon: _driverMarkerIcon!, // Always set by MarkerIcons.busIcon
          anchor: Offset(0.5, 0.5),
          flat: true,
          infoWindow: InfoWindow(
            title: 'Your Location (START)',
            snippet: 'Driver:  _driverName',
          ),
        ),
      );
    }

    // Add passenger markers (passenger icon)
    for (int i = 0; i < routeStops.length; i++) {
      final stop = routeStops[i];
      if (stop.id != 'bus') {
        final passenger = _passengers.firstWhere(
          (p) => p['userId'] == stop.id,
          orElse: () => <String, dynamic>{},
        );

        if (passenger.isNotEmpty && passenger['pickupLocation'] != null) {
          final location = passenger['pickupLocation'];
          final latLng = LatLng(location['latitude'], location['longitude']);

          // Determine icon based on role
          final isDriver = (passenger['role'] == 'driver');
          final markerIcon = isDriver
              ? (_driverMarkerIcon ?? BitmapDescriptor.defaultMarker)
              : (_passengerMarkerIcon ?? BitmapDescriptor.defaultMarker);

          _allMarkers.add(
            Marker(
              markerId: MarkerId('passenger_${passenger['userId']}'),
              position: latLng,
              icon: markerIcon,
              anchor: Offset(0.5, 0.5),
              flat: true,
              infoWindow: InfoWindow(
                title: 'Stop $i: ${passenger['userName']}',
                snippet:
                    '${passenger['selectedSeats'].length} seats • ${passenger['pickupAddress']}',
              ),
              onTap: () => _showPassengerDetails(passenger),
            ),
          );
        }
      }
    }
  }

  // Show route summary in a card on screen
  void _displayRouteSummary(
    double totalDistance,
    List<som.BusStop> routeStops,
  ) {
    setState(() {
      _showRouteSummary = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeDriverScreen();
    // Set up periodic refresh for passengers
    _passengerRefreshTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      if (mounted) {
        _loadPassengers();
      }
    });
  }

  Future<void> _initializeDriverScreen() async {
    await _loadMarkerIcons();
    await _loadDriverData();
  }

  @override
  void dispose() {
    // Cancel passenger refresh timer
    _passengerRefreshTimer?.cancel();

    // Dispose map controller properly
    _mapController?.dispose();

    // Clear any pending operations
    if (_controller.isCompleted) {
      _controller.future.then((controller) {
        try {
          controller.dispose();
        } catch (e) {
          print('Error disposing map controller: $e');
        }
      });
    }

    // Stop the flowing animation timer
    _stopFlowingAnimation();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Driver Map',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF576238),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _isOnline
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
            ),
            onPressed: _toggleOnlineStatus,
            tooltip: _isOnline ? 'Go Offline' : 'Go Online',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(
              _showRouteSummary ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              setState(() {
                _showRouteSummary = !_showRouteSummary;
              });
            },
            tooltip: _showRouteSummary ? 'Hide Route' : 'Show Route',
          ),
          IconButton(
            icon: Icon(_isAnimating ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              if (_isAnimating) {
                _stopFlowingAnimation();
              } else {
                _startFlowingAnimation();
              }
            },
            tooltip: _isAnimating ? 'Pause Animation' : 'Start Animation',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: const Color(0xFF576238)),
                  SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Driver Status Card
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF576238),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.directions_bus,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Driver Dashboard',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  _driverBus?.numberPlate ?? 'No bus assigned',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isOnline ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_driverBus != null) ...[
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.route,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_driverBus!.startPoint} → ${_driverBus!.destination}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '${_passengers.fold<int>(0, (total, passenger) => total + ((passenger['adultCount'] as int? ?? 1) + (passenger['childrenCount'] as int? ?? 0)))} passengers',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Map
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          GoogleMap(
                            onMapCreated: (GoogleMapController controller) {
                              _controller.complete(controller);
                              _mapController = controller;
                            },
                            initialCameraPosition: _initialPosition,
                            markers: _allMarkers,
                            polylines: _allPolylines,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            onTap: (LatLng location) {
                              // Handle map tap if needed
                            },
                          ),
                          if (_isLoadingRoute)
                            const Center(child: CircularProgressIndicator()),

                          // Zoom controls
                          MapZoomControls(mapController: _mapController),

                          // Flowing Route Legend
                          if (_allPolylines.isNotEmpty)
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth: 200,
                                    minWidth: 150,
                                  ),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.water_drop,
                                            size: 16,
                                            color: Colors.blue.shade600,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Flowing Route',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF111827),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _isAnimating
                                                  ? Colors.green.shade100
                                                  : Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: _isAnimating
                                                        ? Colors.green
                                                        : Colors.grey,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  _isAnimating
                                                      ? 'Live'
                                                      : 'Paused',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: _isAnimating
                                                        ? Colors.green.shade700
                                                        : Colors.grey.shade700,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      // Main bus route
                                      Row(
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 
                                                0.6,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Main Route',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      // Pickup route
                                      Row(
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade600,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Pickup Route',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      // Final destination
                                      Row(
                                        children: [
                                          Container(
                                            width: 16,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade600,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Final Destination',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          // Google Maps style circular buttons (stacked vertically on bottom right)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Material(
                              color: Colors.transparent,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // My Location button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      onPressed: _isLoadingLocation
                                          ? null
                                          : _getCurrentLocation,
                                      icon: _isLoadingLocation
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.grey),
                                              ),
                                            )
                                          : Icon(
                                              Icons.my_location,
                                              color: Colors.grey[700],
                                            ),
                                      tooltip: 'My Location',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        padding: EdgeInsets.all(12),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  // Refresh button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      onPressed: _refreshData,
                                      icon: Icon(
                                        Icons.refresh,
                                        color: Colors.white,
                                      ),
                                      tooltip: 'Refresh Data',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        padding: EdgeInsets.all(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
*/
