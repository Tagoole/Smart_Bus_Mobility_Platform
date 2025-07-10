import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:smart_bus_mobility_platform1/resources/bus_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:smart_bus_mobility_platform1/resources/map_service.dart' as som;
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_model.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';

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
  bool _isLoadingLocation = false;
  bool _isOnline = false;

  // Passengers data
  List<Map<String, dynamic>> _passengers = [];
  final Set<Marker> _allMarkers = {};
  Directions? _routeInfo;
  bool _isLoadingRoute = false;

  // UI state
  bool _isLoading = true;
  String _statusMessage = 'Loading...';

  // Route summary data
  double _totalRouteDistance = 0.0;
  List<som.BusStop> _optimizedRouteStops = [];
  bool _showRouteSummary = false;
  final Set<Polyline> _allPolylines = {}; // Add this for multiple polylines

  // Timers for periodic updates
  Timer? _passengerRefreshTimer;
  Timer? _locationUpdateTimer;

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
            'Please check your browser location settings and try again.';
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
      // Update driver location in drivers collection
      await FirebaseFirestore.instance.collection('drivers').doc(_driverId).set(
        {
          'currentLocation': {
            'latitude': _driverLocation!.latitude,
            'longitude': _driverLocation!.longitude,
          },
          'isOnline': _isOnline,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Also update bus location if driver has an assigned bus
      if (_driverBus != null) {
        await _busService.updateBusLocation(
          _driverBus!.busId,
          _driverLocation!.latitude,
          _driverLocation!.longitude,
        );
      }
    } catch (e) {
      print('Error updating driver/bus location: $e');
    }
  }

  // Update all markers on the map
  void _updateMarkers() {
    _allMarkers.clear();

    // Add driver location marker
    if (_driverLocation != null && _driverMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('driver_location'),
          position: _driverLocation!,
          icon: _driverMarkerIcon!,
          anchor: Offset(0.5, 0.5), // Center the marker
          flat: true, // Keep marker flat (not tilted)
          infoWindow: InfoWindow(
            title: 'Your Location (START)',
            snippet: 'Driver: $_driverName',
          ),
        ),
      );
    }

    // Add passenger markers
    for (int i = 0; i < _passengers.length; i++) {
      final passenger = _passengers[i];
      if (passenger['pickupLocation'] != null && _passengerMarkerIcon != null) {
        final location = passenger['pickupLocation'];
        final latLng = LatLng(location['latitude'], location['longitude']);

        _allMarkers.add(
          Marker(
            markerId: MarkerId('passenger_${passenger['userId']}'),
            position: latLng,
            icon: _passengerMarkerIcon!,
            anchor: Offset(0.5, 0.5), // Center the marker
            flat: true, // Keep marker flat (not tilted)
            infoWindow: InfoWindow(
              title: 'Passenger ${i + 1}: ${passenger['userName']}',
              snippet:
                  '${passenger['selectedSeats'].length} seats • ${passenger['pickupAddress']}',
            ),
            onTap: () => _showPassengerDetails(passenger),
          ),
        );
      }
    }
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

  /// Fetches the route polyline from Google Directions API and updates _routeInfo
  Future<void> _fetchRoutePolyline(LatLng start, LatLng end) async {
    setState(() {
      _isLoadingRoute = true;
    });
    try {
      final directions = await DirectionsRepository().getDirections(
        origin: start,
        destination: end,
      );
      setState(() {
        _routeInfo = directions;
        _isLoadingRoute = false;
      });
    } catch (e) {
      print('Error fetching route polyline: $e');
      setState(() {
        _routeInfo = null;
        _isLoadingRoute = false;
      });
    }
  }

  // Add this function to draw all polylines automatically
  Future<void> _drawAllPassengerPolylines() async {
    if (_driverLocation == null) return;
    Set<Polyline> polylines = {};
    int polylineId = 0;
    for (final passenger in _passengers) {
      if (passenger['pickupLocation'] != null) {
        final location = passenger['pickupLocation'];
        final LatLng passengerLatLng = LatLng(
          location['latitude'],
          location['longitude'],
        );
        await _fetchRoutePolyline(_driverLocation!, passengerLatLng);
      }
    }
    setState(() {
      // _allPolylines.clear(); // This line is removed as per the edit hint
      // _allPolylines.addAll(polylines); // This line is removed as per the edit hint
    });
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
      await _getCurrentLocation();

      setState(() {
        _isLoading = false;
        _statusMessage = 'Refresh completed';
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

  // Add this function to compute and draw the SOM optimal route
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

    // Create multiple polylines for better visualization
    _allPolylines.clear();

    // Main optimized route polyline
    _allPolylines.add(
      Polyline(
        polylineId: PolylineId('optimal_som_route'),
        points: routeCoords,
        color: Colors.deepPurple,
        width: 6,
        geodesic: true,
      ),
    );

    // Add segment polylines with different colors for each pickup
    final List<Color> segmentColors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.cyan,
    ];

    for (int i = 0; i < routeCoords.length - 1; i++) {
      final colorIndex = i % segmentColors.length;
      _allPolylines.add(
        Polyline(
          polylineId: PolylineId('route_segment_$i'),
          points: [routeCoords[i], routeCoords[i + 1]],
          color: segmentColors[colorIndex],
          width: 4,
          geodesic: true,
        ),
      );
    }

    setState(() {
      // _allPolylines.clear(); // This line is removed as per the edit hint
      // _allPolylines.add(
      //   // This line is removed as per the edit hint
      //   Polyline(
      //     // This line is removed as per the edit hint
      //     polylineId: PolylineId(
      //       'optimal_som_route',
      //     ), // This line is removed as per the edit hint
      //     points: routeCoords, // This line is removed as per the edit hint
      //     color: Colors.deepPurple, // This line is removed as per the edit hint
      //     width: 5, // This line is removed as per the edit hint
      //   ), // This line is removed as per the edit hint
      // ); // This line is removed as per the edit hint
    });

    // Show route summary
    _displayRouteSummary(totalDistance, optimizedRoute.orderedStops);
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

    // Add driver location marker
    if (_driverLocation != null && _driverMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('driver_location'),
          position: _driverLocation!,
          icon: _driverMarkerIcon!,
          anchor: Offset(0.5, 0.5), // Center the marker
          flat: true, // Keep marker flat (not tilted)
          infoWindow: InfoWindow(
            title: 'Your Location (START)',
            snippet: 'Driver: $_driverName',
          ),
        ),
      );
    }

    // Add passenger markers with route order
    for (int i = 0; i < routeStops.length; i++) {
      final stop = routeStops[i];
      if (stop.id != 'bus') {
        // Find the passenger data
        final passenger = _passengers.firstWhere(
          (p) => p['userId'] == stop.id,
          orElse: () => <String, dynamic>{},
        );

        if (passenger.isNotEmpty &&
            passenger['pickupLocation'] != null &&
            _passengerMarkerIcon != null) {
          final location = passenger['pickupLocation'];
          final latLng = LatLng(location['latitude'], location['longitude']);

          _allMarkers.add(
            Marker(
              markerId: MarkerId('passenger_${passenger['userId']}'),
              position: latLng,
              icon: _passengerMarkerIcon!,
              anchor: Offset(0.5, 0.5), // Center the marker
              flat: true, // Keep marker flat (not tilted)
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
      _totalRouteDistance = totalDistance;
      _optimizedRouteStops = routeStops;
      _showRouteSummary = true;
    });
  }

  @override
  void initState() {
    super.initState();

    // Add a timeout to prevent infinite loading
    Timer(Duration(seconds: 30), () {
      if (mounted && _isLoading) {
        print('Loading timeout reached, forcing completion');
        setState(() {
          _isLoading = false;
          _statusMessage = 'Loading completed with timeout';
        });
      }
    });

    _loadMarkerIcons();
    _loadDriverData();
    _getCurrentLocation();

    // Set up periodic refresh for passengers
    _passengerRefreshTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      if (mounted) {
        _loadPassengers();
      }
    });

    // Set up frequent location updates for real-time tracking
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted && _isOnline) {
        _getCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    // Cancel all timers
    _passengerRefreshTimer?.cancel();
    _locationUpdateTimer?.cancel();

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
                        color: Colors.black.withOpacity(0.1),
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
                                  _driverName,
                                  style: TextStyle(
                                    fontSize: 18,
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
                              '${_passengers.length} passengers',
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
                          color: Colors.black.withOpacity(0.1),
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

                          // Route Summary Card
                          if (_showRouteSummary &&
                              _optimizedRouteStops.isNotEmpty)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                width: 320,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.white, Colors.grey.shade50],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                      spreadRadius: 2,
                                    ),
                                    BoxShadow(
                                      color: Colors.deepPurple.withOpacity(0.1),
                                      blurRadius: 30,
                                      offset: Offset(0, 15),
                                      spreadRadius: 5,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.deepPurple.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header with gradient
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.deepPurple.shade600,
                                            Colors.deepPurple.shade800,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                          topRight: Radius.circular(20),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.alt_route_rounded,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'OPTIMIZED ROUTE',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  'Follow this order for efficiency',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _showRouteSummary = false;
                                              });
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.close_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Distance Card
                                    Container(
                                      margin: EdgeInsets.all(16),
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.green.shade50,
                                            Colors.green.shade100,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade600,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.speed_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'TOTAL DISTANCE',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        Colors.green.shade700,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                SizedBox(height: 2),
                                                Text(
                                                  '${_totalRouteDistance.toStringAsFixed(1)} km',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        Colors.green.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Route Stops
                                    Container(
                                      margin: EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons
                                                    .format_list_numbered_rounded,
                                                size: 16,
                                                color:
                                                    Colors.deepPurple.shade600,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'STOPS ORDER',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors
                                                      .deepPurple
                                                      .shade600,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),

                                          Container(
                                            constraints: BoxConstraints(
                                              maxHeight: 180,
                                            ),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: _optimizedRouteStops.asMap().entries.map((
                                                  entry,
                                                ) {
                                                  final index = entry.key;
                                                  final stop = entry.value;
                                                  final isStart = index == 0;

                                                  return Container(
                                                    margin: EdgeInsets.only(
                                                      bottom: 8,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        // Stop number indicator
                                                        Container(
                                                          width: 32,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            gradient: LinearGradient(
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                              colors: isStart
                                                                  ? [
                                                                      Colors
                                                                          .blue
                                                                          .shade500,
                                                                      Colors
                                                                          .blue
                                                                          .shade700,
                                                                    ]
                                                                  : [
                                                                      Colors
                                                                          .deepPurple
                                                                          .shade400,
                                                                      Colors
                                                                          .deepPurple
                                                                          .shade600,
                                                                    ],
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  16,
                                                                ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color:
                                                                    (isStart
                                                                            ? Colors.blue
                                                                            : Colors.deepPurple)
                                                                        .withOpacity(
                                                                          0.3,
                                                                        ),
                                                                blurRadius: 8,
                                                                offset: Offset(
                                                                  0,
                                                                  4,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Center(
                                                            child: Text(
                                                              '${index + 1}',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                              ),
                                                            ),
                                                          ),
                                                        ),

                                                        SizedBox(width: 12),

                                                        // Stop details
                                                        Expanded(
                                                          child: Container(
                                                            padding:
                                                                EdgeInsets.all(
                                                                  12,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: isStart
                                                                  ? Colors.blue
                                                                        .withOpacity(
                                                                          0.1,
                                                                        )
                                                                  : Colors
                                                                        .white,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              border: Border.all(
                                                                color: isStart
                                                                    ? Colors
                                                                          .blue
                                                                          .withOpacity(
                                                                            0.3,
                                                                          )
                                                                    : Colors
                                                                          .grey
                                                                          .withOpacity(
                                                                            0.2,
                                                                          ),
                                                                width: 1,
                                                              ),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Icon(
                                                                      isStart
                                                                          ? Icons.directions_bus_rounded
                                                                          : Icons.person_rounded,
                                                                      size: 14,
                                                                      color:
                                                                          isStart
                                                                          ? Colors.blue.shade600
                                                                          : Colors.deepPurple.shade600,
                                                                    ),
                                                                    SizedBox(
                                                                      width: 6,
                                                                    ),
                                                                    Expanded(
                                                                      child: Text(
                                                                        stop.name,
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              13,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              isStart
                                                                              ? Colors.blue.shade700
                                                                              : Colors.grey.shade800,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                if (isStart) ...[
                                                                  SizedBox(
                                                                    height: 4,
                                                                  ),
                                                                  Text(
                                                                    'STARTING POINT',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Colors
                                                                          .blue
                                                                          .shade600,
                                                                      letterSpacing:
                                                                          0.5,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        ],
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

                // Bottom Action Bar
                Container(
                  margin: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingLocation
                                  ? null
                                  : _getCurrentLocation,
                              icon: _isLoadingLocation
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Icon(Icons.my_location),
                              label: Text('My Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF576238),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _refreshData,
                              icon: Icon(Icons.refresh),
                              label: Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _toggleOnlineStatus,
                          icon: Icon(
                            _isOnline ? Icons.visibility_off : Icons.visibility,
                          ),
                          label: Text(_isOnline ? 'Go Offline' : 'Go Online'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isOnline
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
