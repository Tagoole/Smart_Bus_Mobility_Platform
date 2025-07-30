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

  static const CameraPosition _initialPosition = CameraPosition(
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
  final List<Map<String, dynamic>> _removedPassengers =
      []; // Track removed passengers
  final Set<Marker> _allMarkers = {};

  // Polylines and route data
  final Set<Polyline> _polylines = {};
  Directions? _directions;
  final double _totalRouteDistance = 0;
  final double _totalRouteTime = 0;
  Map<String, dynamic>? _nearestPassenger;
  String _routeDistanceText = '';
  String _routeDurationText = '';

  // UI state
  bool _isLoading = true;
  String _statusMessage = 'Loading...';

  // Timer for passenger data refresh
  Timer? _passengerRefreshTimer;
  Timer? _etaRefreshTimer;

  // Simulation state
  bool _isSimulating = false;
  bool _isSimulationPaused = false;
  Timer? _simulationTimer;
  int _simulationIndex = 0;
  List<LatLng> _simulationRoutePoints = [];

  void _startSimulation() {
    if (_isSimulating || _polylines.isEmpty) return;
    // Gather all polyline points into a single list
    List<LatLng> allPoints = [];
    for (final poly in _polylines) {
      allPoints.addAll(poly.points);
    }
    if (allPoints.length < 2) return;
    setState(() {
      _isSimulating = true;
      _isSimulationPaused = false;
      _simulationIndex = 0;
      _simulationRoutePoints = allPoints;
    });
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isSimulationPaused) return;
      if (_simulationIndex < _simulationRoutePoints.length) {
        setState(() {
          _driverLocation = _simulationRoutePoints[_simulationIndex];
          _simulationIndex++;
        });
        _updateMarkers();
      } else {
        timer.cancel();
        setState(() {
          _isSimulating = false;
        });
      }
    });
  }

  void _pauseSimulation() {
    setState(() {
      _isSimulationPaused = true;
    });
  }

  void _resumeSimulation() {
    setState(() {
      _isSimulationPaused = false;
    });
  }

  void _resetSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
      _isSimulationPaused = false;
      _simulationIndex = 0;
      _simulationRoutePoints = [];
    });
    // Optionally reset driver location to start
    if (_polylines.isNotEmpty && _polylines.first.points.isNotEmpty) {
      setState(() {
        _driverLocation = _polylines.first.points.first;
      });
      _updateMarkers();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeDriverScreen();

    // Get driver location as soon as possible
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        _getCurrentLocation();
      }
    });

    // Change the refresh timer to 1 minute
    _passengerRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadPassengers();
      }
    });

    // ETA refresh timer (1.5 minutes)
    _etaRefreshTimer = Timer.periodic(const Duration(seconds: 90), (timer) {
      if (mounted) {
        _updateAllPassengerEtas();
      }
    });

    // Check for Google API key issues
    _checkGoogleApiKey();
  }

  // Check if Google API key is working properly
  Future<void> _checkGoogleApiKey() async {
    if (_driverLocation == null) {
      // Use a default location for testing
      const testOrigin = LatLng(0.34540783865964797, 32.54297125499706);
      const testDestination = LatLng(0.34640783865964797, 32.54397125499706);

      try {
        final directions = await _directionsRepository.getDirections(
          origin: testOrigin,
          destination: testDestination,
        );

        if (directions == null) {
          print('Warning: Google Directions API returned null response');
          _showSnackBar('Warning: Google Maps API may not be working properly');
        } else {
          print('Google Directions API test successful');
        }
      } catch (e) {
        print('Error testing Google Directions API: $e');
        _showSnackBar('Error: Google Maps API not working - ${e.toString()}');
      }
    }
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
      builder: (context) => const AlertDialog(
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
          'Found  [1m${bookingsSnapshot.docs.length} [0m bookings for bus ${_driverBus!.busId}');

      // Use a set to track unique booking IDs to avoid duplicates
      final Set<String> processedBookingIds = {};
      final List<Map<String, dynamic>> passengers = [];

      for (var doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final bookingId = doc.id;
        final userId = bookingData['userId'];

        // Only process bookings with a valid pickupLocation
        if (bookingData['pickupLocation'] == null) {
          print('Skipping booking $bookingId: no pickupLocation');
          continue;
        }

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

      // Only include passengers with valid pickupLocation
      final filteredPassengers = passengers.where((p) => p['pickupLocation'] != null).toList();
      setState(() {
        _passengers = filteredPassengers;
        _isLoading = false;
        if (_passengers.isEmpty) {
          _polylines.clear();
        }
      });

      _updateMarkers();

      // Show success message
      if (_passengers.isEmpty) {
        _showSnackBar('No passengers found for your bus');
      } else {
        _showSnackBar('${_passengers.length} passengers loaded successfully');
      }

      // Debug prints for _loadPassengers
      for (var p in passengers) {
        if (p['pickupLocation'] == null) {
          print('[DEBUG] Booking ${p['bookingId']} for user ${p['userName']} has no pickupLocation and will not be shown on the map.');
        } else {
          final loc = p['pickupLocation'];
          print('[DEBUG] Booking ${p['bookingId']} for user ${p['userName']} at location (${loc['latitude']}, ${loc['longitude']}) will be shown.');
        }
      }

    } catch (e) {
      Navigator.of(context).pop();
      print('Error loading passengers: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error loading passengers:  [31m${e.toString()} [0m';
      });
      _showSnackBar('Error loading passengers: ${e.toString()}');
    }
  }

  // Generate optimized route using BusRouteService
  Future<void> _generateOptimizedRoute() async {
    if (_driverBus == null) {
      print('No bus assigned to driver.');
      _showSnackBar('No bus assigned to you.');
      return;
    }
    if (_passengers.isEmpty) {
      print('No passengers available for route generation');
      _showSnackBar('No passengers available for route generation');
      return;
    }
    if (_driverLocation == null) {
      print('Driver location not available');
      _showSnackBar('Your location is not available');
      return;
    }
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Optimizing route...';
      });
      print('Starting route generation with driver at: (${_driverLocation!.latitude}, ${_driverLocation!.longitude})');
      print('Number of passengers: ${_passengers.length}');
      _routeService.clearAllPassengers();
      _polylines.clear();

      // Build end stop from admin-set destination
      final endStop = map_service.BusStop(
        id: 'end',
        location: map_service.LatLng(_driverBus!.destinationLat!, _driverBus!.destinationLng!),
        name: _driverBus!.destination,
      );

      // Build passenger stops
      final passengerStops = _passengers.map((p) => map_service.BusStop(
        id: p['userId'],
        location: map_service.LatLng(
          p['pickupLocation']['latitude'],
          p['pickupLocation']['longitude'],
        ),
        name: p['pickupAddress'] ?? 'Unknown',
      )).toList();

      // 1. Find the nearest passenger to the DRIVER'S CURRENT LOCATION
      int? nearestIdx;
      double minDistance = double.infinity;
      for (int i = 0; i < passengerStops.length; i++) {
        final stop = passengerStops[i];
        final dLat = stop.location.latitude - _driverLocation!.latitude;
        final dLng = stop.location.longitude - _driverLocation!.longitude;
        final distance = (dLat * dLat) + (dLng * dLng); // squared distance
        if (distance < minDistance) {
          minDistance = distance;
          nearestIdx = i;
        }
      }
      if (nearestIdx == null) {
        print('No valid nearest passenger found.');
        _showSnackBar('No valid nearest passenger found.');
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
        return;
      }
      final nearestPassenger = passengerStops[nearestIdx];
      // Remove nearest passenger from the list for SOM
      final remainingPassengers = List<map_service.BusStop>.from(passengerStops)..removeAt(nearestIdx);

      // 2. Optimize only the remaining passenger stops using the greedy optimizer
      List<map_service.BusStop> optimizedPickups = [];
      if (remainingPassengers.isNotEmpty) {
        // Use greedy optimizer for the remaining passengers
        final coords = remainingPassengers.map((s) => map_service.LatLng(s.location.latitude, s.location.longitude)).toList();
        final greedyOrder = _routeService.getGreedyRouteOrder(coords);
        optimizedPickups = greedyOrder.map((i) => remainingPassengers[i]).toList();
      }

      // 3. Final ordered stops: DRIVER LOCATION, nearest passenger, optimized pickups, end
      final orderedStops = [
        map_service.BusStop(
          id: 'driver',
          location: map_service.LatLng(_driverLocation!.latitude, _driverLocation!.longitude),
          name: 'Driver Location',
        ),
        nearestPassenger,
        ...optimizedPickups,
        endStop
      ];
      print('[DEBUG] Ordered stops for route:');
      final seenLocations = <String, int>{};
      for (var stop in orderedStops) {
        final key = '${stop.location.latitude},${stop.location.longitude}';
        print('  ${stop.name} at ${stop.location}');
        seenLocations[key] = (seenLocations[key] ?? 0) + 1;
      }
      // Check for duplicates
      bool hasDuplicates = false;
      seenLocations.forEach((key, count) {
        if (count > 1) {
          print('[WARNING] Duplicate stop detected at $key, count: $count');
          hasDuplicates = true;
        }
      });
      if (hasDuplicates) {
        print('[ERROR] Duplicate waypoints detected in orderedStops! This may cause circular paths.');
      }

      // 4. Create waypoints for Directions API
      final waypoints = orderedStops.map((s) => LatLng(s.location.latitude, s.location.longitude)).toList();
      await _createWaypointPolyline(waypoints);
      await _findNearestPassengerAndDrawRoute();
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
    } catch (e) {
      print('Error generating optimized route: $e');
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
      _showSnackBar('Error generating route: ${e.toString()}');
    }
  }

  // Create a polyline that follows roads through all waypoints
  Future<void> _createWaypointPolyline(List<LatLng> waypoints) async {
    if (waypoints.length < 2) return;

    print('Creating waypoint polyline with ${waypoints.length} waypoints');
    print('Waypoints: $waypoints');

    try {
      // Always clear previous route polylines before drawing a new one
      setState(() {
        _polylines.removeWhere((polyline) => polyline.polylineId.value == 'full_route');
      });

      // Use a single Directions API call with all waypoints (excluding first and last)
      final origin = waypoints.first;
      final destination = waypoints.last;
      final intermediateWaypoints = waypoints.length > 2 ? waypoints.sublist(1, waypoints.length - 1) : null;

        final directions = await _directionsRepository.getDirections(
          origin: origin,
          destination: destination,
        waypoints: intermediateWaypoints,
        );

      if (directions != null && directions.polylinePoints.isNotEmpty) {
        final fullRoutePoints = directions.polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
        print('Got ${fullRoutePoints.length} polyline points from Directions API');

      setState(() {
        _polylines.add(
          Polyline(
              polylineId: const PolylineId('full_route'),
            points: fullRoutePoints,
            color: Colors.blue,
            width: 5,
            patterns: [
              PatternItem.dash(20),
              PatternItem.gap(10),
            ],
          ),
        );
        });

        // Optionally update total distance/time if available
        if (directions.totalDistance.isNotEmpty) {
          _routeDistanceText = directions.totalDistance;
        }
        if (directions.totalDuration.isNotEmpty) {
          _routeDurationText = directions.totalDuration;
        }

      // Adjust camera to show the route
      if (_mapController != null && fullRoutePoints.isNotEmpty) {
        final bounds = _calculateBounds(fullRoutePoints);
        print('Adjusting camera to bounds: $bounds');
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50),
        );
        }
      } else {
        print('Directions API did not return a valid polyline, falling back to segmented polylines.');
        // Fallback: draw segmented polylines between each pair of waypoints
        List<LatLng> allPoints = [];
        for (int i = 0; i < waypoints.length - 1; i++) {
          final segOrigin = waypoints[i];
          final segDest = waypoints[i + 1];
          final segDirections = await _directionsRepository.getDirections(
            origin: segOrigin,
            destination: segDest,
          );
          if (segDirections != null && segDirections.polylinePoints.isNotEmpty) {
            final segPoints = segDirections.polylinePoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
            // Avoid duplicate points
            if (allPoints.isNotEmpty && allPoints.last == segPoints.first) {
              allPoints.addAll(segPoints.skip(1));
            } else {
              allPoints.addAll(segPoints);
            }
          } else {
            // Fallback: straight line
            allPoints.add(segOrigin);
            allPoints.add(segDest);
          }
        }
        // Only add one polyline for the entire route
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('full_route'),
              points: allPoints,
              color: Colors.red,
              width: 5,
            ),
          );
        });
      }
    } catch (e) {
      print('Error creating waypoint polyline: $e');
    }
  }

  // Create batched polylines for Directions API
  Future<void> _createBatchedWaypointPolylines(List<LatLng> waypoints, {int batchSize = 20}) async {
    if (waypoints.length < 2) return;
    print('Creating batched waypoint polylines with ${waypoints.length} waypoints, batch size $batchSize');
    setState(() {
      _polylines.removeWhere((polyline) => polyline.polylineId.value == 'full_route');
    });
    List<LatLng> allPoints = [];
    int startIdx = 0;
    int polylineIdCounter = 0;
    while (startIdx < waypoints.length - 1) {
      int endIdx = (startIdx + batchSize < waypoints.length - 1)
          ? startIdx + batchSize
          : waypoints.length - 1;
      final origin = waypoints[startIdx];
      final destination = waypoints[endIdx];
      final intermediateWaypoints = endIdx - startIdx > 1
          ? waypoints.sublist(startIdx + 1, endIdx)
          : null;
      final directions = await _directionsRepository.getDirections(
        origin: origin,
        destination: destination,
        waypoints: intermediateWaypoints,
      );
      if (directions != null && directions.polylinePoints.isNotEmpty) {
        final batchPoints = directions.polylinePoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
        if (allPoints.isNotEmpty && allPoints.last == batchPoints.first) {
          allPoints.addAll(batchPoints.skip(1));
        } else {
          allPoints.addAll(batchPoints);
        }
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('full_route_$polylineIdCounter'),
              points: batchPoints,
              color: Colors.blue,
              width: 5,
              patterns: [
                PatternItem.dash(20),
                PatternItem.gap(10),
              ],
            ),
          );
        });
      } else {
        // Fallback: straight line
        allPoints.add(origin);
        allPoints.add(destination);
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('full_route_$polylineIdCounter'),
              points: [origin, destination],
              color: Colors.red,
              width: 5,
            ),
          );
        });
      }
      startIdx = endIdx;
      polylineIdCounter++;
    }
  }

  // Calculate bounds for a list of LatLng points
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // Find nearest passenger and draw route
  Future<void> _findNearestPassengerAndDrawRoute() async {
    if (_driverLocation == null) {
      print('Cannot find nearest passenger: Driver location is null');
      return;
    }

    if (_passengers.isEmpty) {
      print('Cannot find nearest passenger: No passengers available');
      return;
    }

    try {
      print('Finding nearest passenger from ${_passengers.length} passengers');

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
        print(
            'Found nearest passenger: ${nearest['userName']} at ${minDistance.toStringAsFixed(2)} km');
        setState(() {
          _nearestPassenger = nearest;
        });

        // Get directions from Google Directions API
        final location = nearest['pickupLocation'];
        final destination = LatLng(
          location['latitude'],
          location['longitude'],
        );

        print('Getting directions to nearest passenger');
        final directions = await _directionsRepository.getDirections(
          origin: _driverLocation!,
          destination: destination,
        );

        if (directions != null) {
          print(
              'Got directions: ${directions.totalDistance}, ${directions.totalDuration}');
          setState(() {
            _directions = directions;
            _routeDistanceText = directions.totalDistance;
            _routeDurationText = directions.totalDuration;
          });

          // Create polyline from directions
          final points = directions.polylinePoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          print('Created polyline with ${points.length} points');

          // Remove any existing nearest passenger route polyline
          _polylines.removeWhere((polyline) =>
              polyline.polylineId.value == 'nearest_passenger_route');

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('nearest_passenger_route'),
                points: points,
                color: Colors.green,
                width: 5,
                zIndex: 2, // Make sure it's drawn on top
              ),
            );
          });

          // Don't adjust camera here - we want to see the full route
        } else {
          print('Failed to get directions to nearest passenger');
        }
      } else {
        print('No nearest passenger found with valid location');
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
        timeLimit: const Duration(seconds: 10),
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
      _driverLocation = const LatLng(0.34540783865964797, 32.54297125499706);
      _isLoadingLocation = false;
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          const CameraPosition(
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

    // Map to count bookings per pickup location
    final Map<String, int> locationCounts = {};
    for (var passenger in _passengers) {
      if (passenger['pickupLocation'] != null) {
        final loc = passenger['pickupLocation'];
        final key = '${loc['latitude']},${loc['longitude']}';
        locationCounts[key] = (locationCounts[key] ?? 0) + 1;
      }
    }

    // Add driver location marker
    if (_driverLocation != null && _driverMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: const MarkerId('driver_location'),
          position: _driverLocation!,
          icon: _driverMarkerIcon!,
          anchor: const Offset(0.5, 0.5),
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
        final key = '${location['latitude']},${location['longitude']}';
        final count = locationCounts[key] ?? 1;

        // Always use the custom passenger icon
        final icon = _passengerMarkerIcon ?? BitmapDescriptor.defaultMarker;

        final eta = _passengerEtas[bookingId] ?? 'Calculating...';

        _allMarkers.add(
          Marker(
            markerId: MarkerId('booking_$bookingId'),
            position: latLng,
            icon: icon,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            infoWindow: InfoWindow(
              title: 'Passenger ${i + 1}: $userName',
              snippet:
                  '${selectedSeats.length} seats • $totalPassengers people • ${passenger['pickupAddress']}${count > 1 ? ' (Overlapping)' : ''}\nETA: $eta',
            ),
            onTap: () => _showPassengerDetails(passenger),
          ),
        );
      }
    }
    setState(() {});

    // Debug prints for _updateMarkers
    for (int i = 0; i < _passengers.length; i++) {
      final passenger = _passengers[i];
      if (passenger['pickupLocation'] != null) {
        final location = passenger['pickupLocation'];
        print('[DEBUG] Adding marker for booking ${passenger['bookingId']} at (${location['latitude']}, ${location['longitude']})');
      }
    }
  }

  // Remove passenger from the map and route
  Future<void> _removePassenger(Map<String, dynamic> passenger) async {
    final bookingId = passenger['bookingId'];
    final userName = passenger['userName'] ?? 'Passenger';

    // Show confirmation dialog
    bool confirmed = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove Passenger'),
            content: Text(
                'Are you sure you want to remove $userName from the route?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    // Check if we're removing the nearest passenger
    bool wasNearestPassenger = false;
    if (_nearestPassenger != null &&
        _nearestPassenger!['bookingId'] == bookingId) {
      wasNearestPassenger = true;
      setState(() {
        _nearestPassenger = null;
      });

      // Remove the nearest passenger route polyline
      _polylines.removeWhere(
          (polyline) => polyline.polylineId.value == 'nearest_passenger_route');
    }

    // Add to removed passengers list
    _removedPassengers.add(Map<String, dynamic>.from(passenger));

    // Remove from local list
    setState(() {
      _passengers.removeWhere((p) => p['bookingId'] == bookingId);
      if (_passengers.isEmpty) {
        _polylines.clear();
      }
    });

    // Update markers
    _updateMarkers();

    // Regenerate route if we still have passengers
    if (_passengers.isNotEmpty && _driverLocation != null) {
      _showSnackBar('Regenerating route without $userName...');
      await _generateOptimizedRoute();

      // If we removed the nearest passenger, find a new nearest passenger
      if (wasNearestPassenger) {
        await _findNearestPassengerAndDrawRoute();
      }
    } else {
      // Clear polylines if no passengers left
      setState(() {
        _polylines.clear();
        _nearestPassenger = null;
        _routeDistanceText = '';
        _routeDurationText = '';
      });
    }

    _showSnackBar('Removed $userName from the route');
  }

  // Restore a removed passenger
  Future<void> _restorePassenger(Map<String, dynamic> passenger) async {
    final bookingId = passenger['bookingId'];
    final userName = passenger['userName'] ?? 'Passenger';

    // Remove from removed list
    _removedPassengers.removeWhere((p) => p['bookingId'] == bookingId);

    // Add back to passengers list
    _passengers.add(passenger);

    // Update markers
    _updateMarkers();

    // Regenerate route
    if (_driverLocation != null) {
      _showSnackBar('Regenerating route with $userName...');
      await _generateOptimizedRoute();
    }

    _showSnackBar('Restored $userName to the route');
  }

  // Show removed passengers list
  void _showRemovedPassengersList() {
    if (_removedPassengers.isEmpty) {
      _showSnackBar('No removed passengers');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
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
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Removed Passengers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_removedPassengers.length} removed',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // List of removed passengers
            Expanded(
              child: ListView.builder(
                itemCount: _removedPassengers.length,
                itemBuilder: (context, index) {
                  final passenger = _removedPassengers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      child: const Icon(Icons.person_off, color: Colors.red),
                    ),
                    title: Text(
                      passenger['userName'] ?? 'Passenger',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        Text(passenger['pickupAddress'] ?? 'Unknown location'),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Restore'),
                      onPressed: () {
                        Navigator.pop(context);
                        _restorePassenger(passenger);
                      },
                    ),
                  );
                },
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show passenger details dialog
  void _showPassengerDetails(Map<String, dynamic> passenger) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Passenger Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${passenger['userName']}'),
            const SizedBox(height: 8),
            Text('Email: ${passenger['userEmail']}'),
            const SizedBox(height: 8),
            Text('Pickup: ${passenger['pickupAddress']}'),
            const SizedBox(height: 8),
            Text('Seats: ${passenger['selectedSeats'].join(', ')}'),
            const SizedBox(height: 8),
            Text(
              'Passengers: ${passenger['adultCount']} Adults, ${passenger['childrenCount']} Children',
            ),
            const SizedBox(height: 8),
            Text(
              'Total Fare: UGX ${passenger['totalFare'].toStringAsFixed(0)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removePassenger(passenger);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Remove'),
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
            child: const Text('Navigate'),
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
      Timer(const Duration(seconds: 2), () {
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
    _etaRefreshTimer?.cancel();
    if (_mapController != null) {
      _mapController!.dispose();
    }
    super.dispose();
  }

  // Store ETAs for each passenger by bookingId
  final Map<String, String> _passengerEtas = {};

  Future<void> _updateAllPassengerEtas() async {
    if (_driverLocation == null) return;
    for (var passenger in _passengers) {
      final bookingId = passenger['bookingId'];
      final pickup = passenger['pickupLocation'];
      if (pickup != null) {
        final pickupLatLng = LatLng(pickup['latitude'], pickup['longitude']);
        final directions = await _directionsRepository.getDirections(
          origin: _driverLocation!,
          destination: pickupLatLng,
        );
        final eta = directions?.totalDuration ?? 'N/A';
        setState(() {
          _passengerEtas[bookingId] = eta;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                  if (_statusMessage.contains('No bus assigned'))
                    ElevatedButton(
                      onPressed: _updateBusIsAvailable,
                      child: const Text('Update Bus'),
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
                ),

                if (_isLoadingLocation)
                  const Center(child: CircularProgressIndicator()),

                // Add notification/button to load passengers
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () async {
                          // First make sure we have the driver's location
                          if (_driverLocation == null) {
                            await _getCurrentLocation();
                          }

                          // Then load passengers
                          await _loadPassengers();

                          // Generate route if we have both location and passengers
                          if (_driverLocation != null &&
                              _passengers.isNotEmpty) {
                            await _generateOptimizedRoute();
                            _showPassengerList();
                          } else {
                            if (_driverLocation == null) {
                              _showSnackBar(
                                  'Unable to get your location. Please try again.');
                            } else if (_passengers.isEmpty) {
                              _showSnackBar(
                                  'No passengers found for your bus.');
                            }
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Load Passengers & Generate Route',
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
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add, color: Colors.black87),
                          onPressed: () {
                            _mapController?.animateCamera(
                              CameraUpdate.zoomIn(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
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
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.remove, color: Colors.black87),
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
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: _isLoadingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.my_location, color: Colors.white),
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
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.people, color: Colors.white),
                          onPressed: _showPassengerList,
                        ),
                        if (_passengers.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_passengers.length}',
                                style: const TextStyle(
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

                // Removed passengers button
                if (_removedPassengers.isNotEmpty)
                  Positioned(
                    bottom: 16,
                    left: 76,
                    child: Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.person_off, color: Colors.white),
                            onPressed: _showRemovedPassengersList,
                            tooltip: 'Show removed passengers',
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_removedPassengers.length}',
                                style: const TextStyle(
                                  color: Colors.red,
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
              
                // Simulation controls (circular, above passenger list button)
                Positioned(
                  bottom: 80, // above the blue passenger list button
                  left: 16,
                  child: Column(
                    children: [
                      if (!_isSimulating && _polylines.isNotEmpty)
                        Container(
                          height: 50,
                          width: 50,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                  ),
              ],
            ),
                          child: IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.green),
                            onPressed: _startSimulation,
                            tooltip: 'Simulate Driver Movement',
                          ),
                        ),
                      if (_isSimulating && !_isSimulationPaused)
                        Container(
                          height: 50,
                          width: 50,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.pause, color: Colors.orange),
                            onPressed: _pauseSimulation,
                            tooltip: 'Pause Simulation',
                          ),
                        ),
                      if (_isSimulating && _isSimulationPaused)
                        Container(
                          height: 50,
                          width: 50,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.play_arrow, color: Colors.green),
                            onPressed: _resumeSimulation,
                            tooltip: 'Resume Simulation',
                          ),
                        ),
                      if (_isSimulating)
                        Container(
                          height: 50,
                          width: 50,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.stop, color: Colors.red),
                            onPressed: _resetSimulation,
                            tooltip: 'Reset Simulation',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            )
    
  );}

  // Show passenger list bottom sheet
  void _showPassengerList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
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
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
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
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
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

            // Make the rest of the content scrollable
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Route regeneration button
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.amber.withOpacity(0.2),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          // First check if we have the driver's location
                          if (_driverLocation == null) {
                            Navigator.pop(context); // Dismiss the sheet
                            _showSnackBar('Getting your location...');
                            await _getCurrentLocation();

                            if (_driverLocation == null) {
                              _showSnackBar(
                                  'Unable to get your location. Please try again.');
                              return;
                            }
                          }

                          // Check if we have passengers
                          if (_passengers.isEmpty) {
                            Navigator.pop(context); // Dismiss the sheet
                            _showSnackBar(
                                'No passengers found. Loading passengers...');
                            await _loadPassengers();

                            if (_passengers.isEmpty) {
                              _showSnackBar(
                                  'No passengers found for your bus.');
                              return;
                            }
                          }

                          // Now generate the route
                          Navigator.pop(context); // Dismiss the sheet
                          _showSnackBar('Generating optimized route...');
                          await _generateOptimizedRoute();
                          _showSnackBar('Route regenerated successfully');
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Regenerate Route'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black87,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                      ),
                    ),

                    // Route information
                    if (_totalRouteDistance > 0)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.blue.withOpacity(0.1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.route, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Full Route (All Passengers)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Distance: ${_totalRouteDistance.toStringAsFixed(1)} km',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Text(
                                      '${_passengers.length} passengers',
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Blue dashed line on map',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Nearest passenger route information
                    if (_nearestPassenger != null &&
                        _routeDistanceText.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.green.withOpacity(0.1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
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
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'To: ${_nearestPassenger!['userName']}',
                                      style: const TextStyle(
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Green solid line on map',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context); // Dismiss the sheet
                                _navigateToPassenger(_nearestPassenger!);
                              },
                              icon: const Icon(Icons.navigation, size: 16),
                              label: const Text('Navigate to Nearest Passenger'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 36),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Bus info
                    if (_driverBus != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.green.withOpacity(0.1),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_bus, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _driverBus!.numberPlate,
                                    style: const TextStyle(
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
                    _passengers.isEmpty
                        ? const SizedBox(
                            height: 200,
                            child: Center(
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
                            ),
                          )
                        : ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: _passengers.length,
                            itemBuilder: (context, index) {
                              final passenger = _passengers[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Colors.blue.withOpacity(0.2),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  title: Text(
                                    passenger['userName'] ?? 'Passenger',
                                    style:
                                        const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(passenger['userEmail'] ?? ''),
                                      Text(
                                        'Booking ID: ${passenger['bookingId']}',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                      Text(
                                        'Seats: ${(passenger['selectedSeats'] as List).join(', ')}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        'Pickup: ${passenger['pickupAddress']}',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${passenger['adultCount']} adult${passenger['adultCount'] > 1 ? 's' : ''}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          if ((passenger['childrenCount'] ??
                                                  0) >
                                              0)
                                            Text(
                                              '${passenger['childrenCount']} child${passenger['childrenCount'] > 1 ? 'ren' : ''}',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline,
                                            size: 20, color: Colors.red),
                                        onPressed: () {
                                          Navigator.pop(
                                              context); // Dismiss the sheet
                                          _removePassenger(passenger);
                                        },
                                        tooltip: 'Remove passenger from route',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.navigation,
                                            size: 20, color: Colors.blue),
                                        onPressed: () {
                                          Navigator.pop(
                                              context); // Dismiss the sheet
                                          _navigateToPassenger(passenger);
                                        },
                                        tooltip: 'Navigate to passenger',
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(context); // Dismiss the sheet
                                    _navigateToPassenger(passenger);
                                  },
                                ),
                              );
                            },
                          ),
                    // Add some padding at the bottom for better scrolling
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}















