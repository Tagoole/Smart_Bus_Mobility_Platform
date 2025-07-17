import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:smart_bus_mobility_platform1/resources/bus_service.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:smart_bus_mobility_platform1/resources/map_service.dart'
    as map_service;
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_model.dart';

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;

  static final CameraPosition _initialPosition = CameraPosition(
    target:
        LatLng(0.34540783865964797, 32.54297125499706), // Kampala coordinates
    zoom: 14,
  );

  // Services
  final BusService _busService = BusService();
  final DirectionsRepository _directionsRepository = DirectionsRepository();
  final map_service.BusRouteService _routeService =
      map_service.BusRouteService();

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

  // Polylines and route data
  final Set<Polyline> _polylines = {};
  Directions? _directions;
  double _totalRouteDistance = 0;
  double _totalRouteTime = 0;
  Map<String, dynamic>? _nearestPassenger;
  String _routeDistanceText = '';
  String _routeDurationText = '';

  // UI state
  bool _isLoading = true;
  String _statusMessage = 'Loading...';

  // Timer for passenger data refresh
  Timer? _passengerRefreshTimer;

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

  Future<void> _loadMarkerIcons() async {
    try {
      _driverMarkerIcon = await MarkerIcons.busIcon;
      _passengerMarkerIcon = await MarkerIcons.passengerIcon;
    } catch (e) {
      print('Error loading marker icons: $e');
      // Fallback to default markers
      _driverMarkerIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _passengerMarkerIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
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
      print('Looking for bus assigned to driver with email: $_driverEmail');
      final busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driverId', isEqualTo: _driverEmail)
          .limit(1)
          .get();

      if (busSnapshot.docs.isNotEmpty) {
        final busData = busSnapshot.docs.first.data();
        print('Found bus with ID: ${busSnapshot.docs.first.id}');
        print('Bus data: $busData');
        setState(() {
          _driverBus = BusModel.fromJson(busData, busSnapshot.docs.first.id);
        });

        // Load passengers for this bus
        await _loadPassengers();
      } else {
        print('No bus assigned to driver: $_driverEmail');
        print('Trying to find bus with case-insensitive email match...');

        // Try to get all buses and check manually for case-insensitive match
        final allBusesSnapshot =
            await FirebaseFirestore.instance.collection('buses').get();

        bool foundBus = false;
        for (var doc in allBusesSnapshot.docs) {
          final data = doc.data();
          final driverId = data['driverId']?.toString().toLowerCase() ?? '';
          if (driverId == _driverEmail.toLowerCase()) {
            print('Found bus with case-insensitive match. Bus ID: ${doc.id}');
            print('Bus data: $data');
            setState(() {
              _driverBus = BusModel.fromJson(data, doc.id);
            });
            foundBus = true;

            // Load passengers for this bus
            await _loadPassengers();
            break;
          }
        }

        if (!foundBus) {
          setState(() {
            _statusMessage = 'No bus assigned to you';
            _isLoading = false;
          });
        }
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
      _showSnackBar('No bus assigned to you');
      return;
    }

    // Show loading indicator
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading passengers...';
    });

    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading passengers...'),
          ],
        ),
      ),
    );

    try {
      // Clear existing passengers to avoid duplicates
      _passengers.clear();

      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('busId', isEqualTo: _driverBus!.busId)
          .where('status', isEqualTo: 'confirmed')
          .get();

      print(
          'Found ${bookingsSnapshot.docs.length} bookings for bus ${_driverBus!.busId}');

      // Use a set to track unique booking IDs to avoid duplicates
      final Set<String> processedBookingIds = {};
      final List<Map<String, dynamic>> passengers = [];

      for (var doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final bookingId = doc.id;
        final userId = bookingData['userId'];

        // Skip if we've already processed this booking
        if (processedBookingIds.contains(bookingId)) {
          print('Skipping duplicate booking: $bookingId');
          continue;
        }

        processedBookingIds.add(bookingId);

        // Get user data for each booking
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final userName =
              userData['name'] ?? userData['username'] ?? 'Passenger';
          print('Adding passenger: $userName (Booking ID: $bookingId)');

          passengers.add({
            'bookingId': bookingId,
            'userId': userId,
            'userName': userName,
            'userEmail': userData['email'] ?? '',
            'pickupLocation': bookingData['pickupLocation'],
            'pickupAddress': bookingData['pickupAddress'] ?? 'Unknown location',
            'selectedSeats': bookingData['selectedSeats'] ?? [],
            'totalFare': bookingData['totalFare'] ?? 0.0,
            'departureDate': bookingData['departureDate'],
            'adultCount': bookingData['adultCount'] ?? 1,
            'childrenCount': bookingData['childrenCount'] ?? 0,
            'role': userData['role'],
          });
        }
      }

      // Close the loading dialog
      Navigator.of(context).pop();

      setState(() {
        _passengers = passengers;
        _isLoading = false;
      });

      _updateMarkers();

      // Show success message
      if (_passengers.isEmpty) {
        _showSnackBar('No passengers found for your bus');
      } else {
        _showSnackBar('${_passengers.length} passengers loaded successfully');
      }

      // Generate optimized route if we have passengers and driver location
      if (_passengers.isNotEmpty && _driverLocation != null) {
        await _generateOptimizedRoute();
      }
    } catch (e) {
      // Close the loading dialog
      Navigator.of(context).pop();

      print('Error loading passengers: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error loading passengers: ${e.toString()}');
    }
  }

  // Generate optimized route using BusRouteService
  Future<void> _generateOptimizedRoute() async {
    if (_driverLocation == null) return;

    try {
      // Clear previous route data
      _routeService.clearAllPassengers();

      // Add driver's current location as starting point
      final driverStop = map_service.BusStop(
        id: 'driver',
        location: map_service.LatLng(
            _driverLocation!.latitude, _driverLocation!.longitude),
        name: 'Driver Location',
      );

      // Add all visible passengers to the route service
      for (var passenger in _passengers) {
        if (passenger['pickupLocation'] != null) {
          final location = passenger['pickupLocation'];
          final latLng = map_service.LatLng(
            location['latitude'],
            location['longitude'],
          );

          _routeService.addPassengerPickup(
            passenger['userId'],
            latLng,
            passenger['pickupAddress'] ?? 'Unknown location',
          );
        }
      }

      // Add bus destination if available
      if (_driverBus != null &&
          _driverBus!.destinationLat != null &&
          _driverBus!.destinationLng != null) {
        final destinationStop = map_service.BusStop(
          id: 'destination',
          location: map_service.LatLng(
            _driverBus!.destinationLat!,
            _driverBus!.destinationLng!,
          ),
          name: _driverBus!.destination,
        );
      }

      // Force optimization
      await _routeService.optimizeNow();

      // Get optimized route coordinates
      final routeCoordinates = _routeService.getOptimizedRouteCoordinates();

      // Convert to Google Maps LatLng
      final googleMapCoordinates = routeCoordinates
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      // Get total distance and time
      _totalRouteDistance = _routeService.getEstimatedTotalDistance() ?? 0;
      _totalRouteTime = _routeService.getEstimatedTotalTime() ?? 0;

      // Create polyline
      setState(() {
        _polylines.clear();

        if (googleMapCoordinates.length > 1) {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('optimized_route'),
              points: googleMapCoordinates,
              color: Colors.blue,
              width: 5,
              patterns: [
                PatternItem.dash(20),
                PatternItem.gap(10),
              ],
            ),
          );
        }
      });

      // Find nearest passenger and draw route
      await _findNearestPassengerAndDrawRoute();
    } catch (e) {
      print('Error generating optimized route: $e');
    }
  }

  // Find nearest passenger and draw route
  Future<void> _findNearestPassengerAndDrawRoute() async {
    if (_driverLocation == null || _passengers.isEmpty) return;

    try {
      // Find the nearest passenger
      Map<String, dynamic>? nearest;
      double minDistance = double.infinity;

      for (var passenger in _passengers) {
        if (passenger['pickupLocation'] != null) {
          final location = passenger['pickupLocation'];
          final passengerLatLng = LatLng(
            location['latitude'],
            location['longitude'],
          );

          // Calculate direct distance (as the crow flies)
          final directDistance = _calculateDistance(
            _driverLocation!.latitude,
            _driverLocation!.longitude,
            passengerLatLng.latitude,
            passengerLatLng.longitude,
          );

          if (directDistance < minDistance) {
            minDistance = directDistance;
            nearest = passenger;
          }
        }
      }

      if (nearest != null) {
        setState(() {
          _nearestPassenger = nearest;
        });

        // Get directions from Google Directions API
        final location = nearest['pickupLocation'];
        final destination = LatLng(
          location['latitude'],
          location['longitude'],
        );

        final directions = await _directionsRepository.getDirections(
          origin: _driverLocation!,
          destination: destination,
        );

        if (directions != null) {
          setState(() {
            _directions = directions;
            _routeDistanceText = directions.totalDistance;
            _routeDurationText = directions.totalDuration;
          });

          // Create polyline from directions
          final points = directions.polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: PolylineId('nearest_passenger_route'),
                points: points,
                color: Colors.green,
                width: 5,
              ),
            );
          });

          // Adjust camera to show the route
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(directions.bounds, 50),
            );
          }
        }
      }
    } catch (e) {
      print('Error finding nearest passenger: $e');
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius of the earth in km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final double distance = earthRadius * c;
    return distance;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied');
      }

      // Get current position with high accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Update camera to driver location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _driverLocation!, zoom: 15),
          ),
        );
      }

      _updateMarkers();
      _updateDriverLocationInFirestore();

      // Generate optimized route if we have passengers
      if (_passengers.isNotEmpty) {
        await _generateOptimizedRoute();
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _driverLocation = LatLng(0.34540783865964797, 32.54297125499706);
      _isLoadingLocation = false;
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(0.34540783865964797, 32.54297125499706),
            zoom: 15,
          ),
        ),
      );
    }

    _updateMarkers();
    _updateDriverLocationInFirestore();
  }

  // Update driver location in Firestore
  Future<void> _updateDriverLocationInFirestore() async {
    if (_driverLocation == null || _driverId == null) return;

    try {
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
              'Bus location updated successfully for bus: ${_driverBus!.busId}');
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
  void _updateMarkers() {
    _allMarkers.clear();

    // Add driver location marker
    if (_driverLocation != null && _driverMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('driver_location'),
          position: _driverLocation!,
          icon: _driverMarkerIcon!,
          anchor: Offset(0.5, 0.5),
          flat: true,
          infoWindow: InfoWindow(
            title: 'Your Location (START)',
            snippet: 'Driver: $_driverName',
          ),
        ),
      );
    }

    // Add passenger markers - one marker per booking
    for (int i = 0; i < _passengers.length; i++) {
      final passenger = _passengers[i];

      if (passenger['pickupLocation'] != null) {
        final location = passenger['pickupLocation'];
        final latLng = LatLng(location['latitude'], location['longitude']);
        final userName = passenger['userName'] ?? 'Passenger';
        final adultCount = passenger['adultCount'] ?? 1;
        final childrenCount = passenger['childrenCount'] ?? 0;
        final totalPassengers = adultCount + childrenCount;
        final selectedSeats = passenger['selectedSeats'] ?? [];
        final bookingId = passenger['bookingId'];

        // Create one marker per booking
        final icon = _passengerMarkerIcon ?? BitmapDescriptor.defaultMarker;

        _allMarkers.add(
          Marker(
            markerId: MarkerId('booking_$bookingId'),
            position: latLng,
            icon: icon,
            anchor: Offset(0.5, 0.5),
            flat: true,
            infoWindow: InfoWindow(
              title: 'Passenger ${i + 1}: $userName',
              snippet:
                  '${selectedSeats.length} seats • ${totalPassengers} people • ${passenger['pickupAddress']}',
            ),
            onTap: () => _showPassengerDetails(passenger),
          ),
        );
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

  // Navigate to passenger
  void _navigateToPassenger(Map<String, dynamic> passenger) async {
    if (passenger['pickupLocation'] == null) {
      _showSnackBar('Passenger pickup location not available');
      return;
    }

    final location = passenger['pickupLocation'];
    if (location == null ||
        location['latitude'] == null ||
        location['longitude'] == null) {
      _showSnackBar('Invalid passenger location data');
      return;
    }

    final LatLng passengerLatLng = LatLng(
      location['latitude'],
      location['longitude'],
    );

    // Move camera
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: passengerLatLng, zoom: 16),
        ),
      );
    }

    _showSnackBar('Navigating to ${passenger['userName']}');
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
      setState(() {
        _isLoading = false;
        _statusMessage = 'Data refreshed';
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
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error refreshing data';
      });
    }
  }

  // Show snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Update bus isAvailable field
  Future<void> _updateBusIsAvailable() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Updating bus...';
    });

    try {
      // Find the bus by driver email
      final busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driverId', isEqualTo: _driverEmail)
          .limit(1)
          .get();

      if (busSnapshot.docs.isEmpty) {
        setState(() {
          _statusMessage = 'No bus found for driver: $_driverEmail';
          _isLoading = false;
        });
        _showSnackBar('No bus found for driver: $_driverEmail');
        return;
      }

      final busDoc = busSnapshot.docs.first;
      final busId = busDoc.id;

      // Update the bus with isAvailable field
      await FirebaseFirestore.instance.collection('buses').doc(busId).update({
        'isAvailable': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSnackBar('Bus updated successfully! Bus ID: $busId');

      // Reload driver data
      await _loadDriverData();
    } catch (e) {
      print('Error updating bus: $e');
      setState(() {
        _statusMessage = 'Error updating bus: $e';
        _isLoading = false;
      });
      _showSnackBar('Error updating bus: $e');
    }
  }

  @override
  void dispose() {
    _passengerRefreshTimer?.cancel();
    if (_mapController != null) {
      _mapController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(_statusMessage),
                  if (_statusMessage.contains('No bus assigned'))
                    ElevatedButton(
                      onPressed: _updateBusIsAvailable,
                      child: Text('Update Bus'),
                    ),
                ],
              ),
            )
          : Stack(
              children: [
                // Full screen map
                GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    // Fix for "Future already completed" error
                    if (!_controller.isCompleted) {
                      _controller.complete(controller);
                    }
                    _mapController = controller;
                  },
                  initialCameraPosition: _initialPosition,
                  markers: _allMarkers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  // Remove the onTap handler that was loading passengers
                ),

                if (_isLoadingLocation)
                  const Center(child: CircularProgressIndicator()),

                // Remove the tap instruction tooltip
                // if (_passengers.isEmpty)
                //   Positioned(
                //     top: 40,
                //     left: 0,
                //     right: 0,
                //     child: Center(
                //       child: Container(
                //         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                //         decoration: BoxDecoration(
                //           color: Colors.black.withOpacity(0.7),
                //           borderRadius: BorderRadius.circular(20),
                //         ),
                //         child: Text(
                //           'Tap on the map to load passengers',
                //           style: TextStyle(
                //             color: Colors.white,
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //       ),
                //     ),
                //   ),

                // Add notification/button to load passengers
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          _loadPassengers().then((_) {
                            if (_passengers.isNotEmpty &&
                                _driverLocation != null) {
                              _generateOptimizedRoute();
                              // Automatically show passenger list
                              _showPassengerList();
                            }
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Load Passengers',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Zoom controls
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: Column(
                    children: [
                      // Zoom in button
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.add, color: Colors.black87),
                          onPressed: () {
                            _mapController?.animateCamera(
                              CameraUpdate.zoomIn(),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 8),
                      // Zoom out button
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.remove, color: Colors.black87),
                          onPressed: () {
                            _mapController?.animateCamera(
                              CameraUpdate.zoomOut(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // My location button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: _isLoadingLocation
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.my_location, color: Colors.white),
                      onPressed:
                          _isLoadingLocation ? null : _getCurrentLocation,
                    ),
                  ),
                ),

                // Passenger list button
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.people, color: Colors.white),
                          onPressed: _showPassengerList,
                        ),
                        if (_passengers.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_passengers.length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Show passenger list bottom sheet
  void _showPassengerList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Passenger List',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${_passengers.length} passengers',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          _loadPassengers().then((_) {
                            _showPassengerList();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Nearest passenger route information
            if (_nearestPassenger != null && _routeDistanceText.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.green.withOpacity(0.1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.directions, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Nearest Passenger Route',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To: ${_nearestPassenger!['userName']}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Distance: $_routeDistanceText',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ETA: $_routeDurationText',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Pickup: ${_nearestPassenger!['pickupAddress']}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _navigateToPassenger(_nearestPassenger!),
                      icon: Icon(Icons.navigation, size: 16),
                      label: Text('Navigate to Nearest Passenger'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 36),
                      ),
                    ),
                  ],
                ),
              ),

            // Route information
            if (_totalRouteDistance > 0)
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.blue.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Optimized Route',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Total Distance: ${_totalRouteDistance.toStringAsFixed(1)} km',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Est. Time: ${_totalRouteTime.toStringAsFixed(0)} min',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${_passengers.length} stops',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Bus info
            if (_driverBus != null)
              Container(
                padding: EdgeInsets.all(16),
                color: Colors.green.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(Icons.directions_bus, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driverBus!.numberPlate,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_driverBus!.startPoint} → ${_driverBus!.destination}',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Passenger list
            Expanded(
              child: _passengers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No passengers found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _passengers.length,
                      itemBuilder: (context, index) {
                        final passenger = _passengers[index];
                        return Card(
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.withOpacity(0.2),
                              child: Icon(
                                Icons.person,
                                color: Colors.blue,
                              ),
                            ),
                            title: Text(
                              passenger['userName'] ?? 'Passenger',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(passenger['userEmail'] ?? ''),
                                Text(
                                  'Booking ID: ${passenger['bookingId']}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                                Text(
                                  'Seats: ${(passenger['selectedSeats'] as List).join(', ')}',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  'Pickup: ${passenger['pickupAddress']}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${passenger['adultCount']} adult${passenger['adultCount'] > 1 ? 's' : ''}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    if ((passenger['childrenCount'] ?? 0) > 0)
                                      Text(
                                        '${passenger['childrenCount']} child${passenger['childrenCount'] > 1 ? 'ren' : ''}',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(Icons.navigation,
                                      size: 20, color: Colors.blue),
                                  onPressed: () =>
                                      _navigateToPassenger(passenger),
                                  tooltip: 'Navigate to passenger',
                                ),
                              ],
                            ),
                            onTap: () => _navigateToPassenger(passenger),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
