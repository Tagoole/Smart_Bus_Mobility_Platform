import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/location_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:smart_bus_mobility_platform1/screens/booking_screen.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:intl/intl.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_model.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';

// return user info so tha checking role is ok

class PassengerMapScreen extends StatefulWidget {
  final bool isPickupSelection;

  const PassengerMapScreen({super.key, this.isPickupSelection = false});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

/*
tarnsfer the latlng screen to an address

*/
class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;
  static final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0.34540783865964797, 32.54297125499706),
    zoom: 14,
  );

  // Variables for pickup location functionality
  LatLng? _userLocation;
  LatLng? _pickupLocation;
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _busMarkerIcon;
  bool _isLoadingLocation = false;
  final Set<Marker> _allMarkers = {};

  // Bus tracking variables
  BusModel? _bookedBus;
  LatLng? _busLocation;
  String _estimatedArrival = 'Calculating...';
  bool _hasActiveBooking = false;
  Timer? _busTrackingTimer;
  Directions? _routeInfo;
  Directions? _originalRouteInfo; // Original route from start to destination
  bool _isLoadingRoute = false;

  // Load custom marker icons
  Future<void> _loadMarkerIcons() async {
    try {
      // Load pickup marker icon - fixed size
      _pickupMarkerIcon = await MarkerIcons.passengerIcon;

      // Load bus marker icon - fixed size
      _busMarkerIcon = await MarkerIcons.busIcon;
    } catch (e) {
      print('Error loading marker icons: $e');
      _pickupMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
      _busMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      );
    }
  }

  // Check for active booking and load bus data
  Future<void> _checkActiveBooking() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'confirmed')
          .where('departureDate', isGreaterThan: DateTime.now())
          .orderBy('departureDate')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final bookingData = snapshot.docs.first.data();
        final busId = bookingData['busId'];

        if (busId != null) {
          // Get bus data
          final busDoc = await FirebaseFirestore.instance
              .collection('buses')
              .doc(busId)
              .get();

          if (busDoc.exists) {
            final busData = busDoc.data()!;
            setState(() {
              _bookedBus = BusModel.fromJson(busData, busId);
              _hasActiveBooking = true;
            });

            // Load pickup location from booking
            if (bookingData['pickupLocation'] != null) {
              final pickup = bookingData['pickupLocation'];
              setState(() {
                _pickupLocation = LatLng(
                  pickup['latitude'],
                  pickup['longitude'],
                );
              });
            }

            // Always show route in pickup selection mode
            if (widget.isPickupSelection) {
              // Fetch original route (start to destination)
              await _fetchOriginalRoutePolyline();

              // Fetch pickup route if pickup is selected
              if (_pickupLocation != null) {
                final startLat = _bookedBus!.startLat ?? 0.0;
                final startLng = _bookedBus!.startLng ?? 0.0;
                await _fetchRoutePolyline(
                  LatLng(startLat, startLng),
                  _pickupLocation!,
                );
              }
            }

            // Start bus tracking
            _startBusTracking();
          }
        }
      }
    } catch (e) {
      print('Error checking active booking: $e');
    }
  }

  // Start bus tracking timer
  void _startBusTracking() {
    _busTrackingTimer?.cancel();
    _busTrackingTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _updateBusLocation();
    });

    // Initial update
    _updateBusLocation();
  }

  // Update bus location and calculate ETA
  Future<void> _updateBusLocation() async {
    if (_bookedBus == null || _pickupLocation == null) return;

    try {
      // Get bus's current location from Firestore
      final busDoc = await FirebaseFirestore.instance
          .collection('buses')
          .doc(_bookedBus!.busId)
          .get();

      if (busDoc.exists) {
        final busData = busDoc.data()!;

        // Check if bus has current location data
        if (busData['currentLocation'] != null) {
          final location = busData['currentLocation'];
          final newBusLocation = LatLng(
            location['latitude'],
            location['longitude'],
          );

          setState(() {
            _busLocation = newBusLocation;
          });

          // Calculate ETA and fetch route polyline
          await _calculateETAAndRoute();
          await _fetchRoutePolyline(_busLocation!, _pickupLocation!);
          _updateMarkers();
        } else {
          // If no current location, use a default location or show message
          print('Bus location not available yet');
          setState(() {
            _estimatedArrival = 'Location unavailable';
            _routeInfo = null;
          });
        }
      }
    } catch (e) {
      print('Error updating bus location: $e');
      setState(() {
        _routeInfo = null;
      });
    }
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

  /// Fetches the original route polyline (start to destination)
  Future<void> _fetchOriginalRoutePolyline() async {
    if (_bookedBus == null) return;

    try {
      final startLat = _bookedBus!.startLat ?? 0.0;
      final startLng = _bookedBus!.startLng ?? 0.0;
      final destLat = _bookedBus!.destinationLat ?? 0.0;
      final destLng = _bookedBus!.destinationLng ?? 0.0;

      final directions = await DirectionsRepository().getDirections(
        origin: LatLng(startLat, startLng),
        destination: LatLng(destLat, destLng),
      );
      setState(() {
        _originalRouteInfo = directions;
      });
    } catch (e) {
      print('Error fetching original route polyline: $e');
      setState(() {
        _originalRouteInfo = null;
      });
    }
  }

  // Calculate ETA and route using Google Directions API
  Future<void> _calculateETAAndRoute() async {
    if (_busLocation == null || _pickupLocation == null) return;

    try {
      // For demo purposes, we'll use a simple calculation
      // In production, you would use Google Directions API
      final distance = _calculateDistance(_busLocation!, _pickupLocation!);
      final estimatedMinutes = (distance / 1000 * 2)
          .round(); // Assuming 30 km/h average speed

      setState(() {
        _estimatedArrival = '$estimatedMinutes min';
      });

      // Generate route polyline (simplified for demo)
      // await _generateRoutePolyline(); // This line is removed
    } catch (e) {
      print('Error calculating ETA: $e');
      setState(() {
        _estimatedArrival = 'Unable to calculate';
      });
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // meters
    final double lat1 = start.latitude * math.pi / 180;
    final double lat2 = end.latitude * math.pi / 180;
    final double deltaLat = (end.latitude - start.latitude) * math.pi / 180;
    final double deltaLon = (end.longitude - start.longitude) * math.pi / 180;

    final double a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(
          'Location services are disabled. Please enable location services.',
        );
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions are denied.');
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions are permanently denied.');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Try to get last known position first (only on mobile platforms)
      if (!kIsWeb) {
        try {
          Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
          if (lastKnownPosition != null) {
            setState(() {
              _userLocation = LatLng(
                lastKnownPosition.latitude,
                lastKnownPosition.longitude,
              );
              _isLoadingLocation = false;
            });

            // Update camera to user location
            if (_controller.isCompleted) {
              GoogleMapController controller = await _controller.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _userLocation!, zoom: 15),
                ),
              );
            }

            _updateMarkers();
            _showSnackBar('Location updated successfully!');
            return;
          }
        } catch (e) {
          print('Last known position not available: $e');
        }
      }

      // If no last known position or on web, try to get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Update camera to user location
      if (_controller.isCompleted) {
        GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _userLocation!, zoom: 15),
          ),
        );
      }

      _updateMarkers();
      _showSnackBar('Location updated successfully!');
    } catch (e) {
      print('Error getting location: $e');
      _showSnackBar('Error getting your location. Please try again.');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // Get current user ID
  String? _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // Add pickup location
  Future<void> _addPickupLocation(LatLng location) async {
    setState(() {
      _pickupLocation = location;
    });
    _updateMarkers();

    // If this is pickup selection mode, don't save to Firestore
    if (widget.isPickupSelection) {
      _showSnackBar('Pickup location selected. Tap "Confirm" to save.');
      return;
    }

    // Save pickup location to Firestore (only for regular mode)
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        _showSnackBar('User not authenticated. Please login again.');
        return;
      }

      // First, deactivate all existing pickup locations for this user
      final existingLocations = await FirebaseFirestore.instance
          .collection('pickup_locations')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      // Deactivate old locations
      for (var doc in existingLocations.docs) {
        await doc.reference.update({'isActive': false});
      }

      // Create location model
      final locationModel = LocationModel.createPickupLocation(
        userId: userId,
        latitude: location.latitude,
        longitude: location.longitude,
        locationName: 'Pickup Location',
        notes: 'Added on ${formatDate(DateTime.now())}',
      );

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('pickup_locations')
          .add(locationModel.toJson());

      print('Pickup location saved with ID: ${docRef.id}');
      _showSnackBar('Pickup location saved successfully!');
    } catch (e) {
      print('Error saving pickup location: $e');
      _showSnackBar('Error saving pickup location. Please try again.');
    }
  }

  // Update all markers on the map
  void _updateMarkers() {
    _allMarkers.clear();

    // Add user location marker
    if (_userLocation != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('user_location'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          anchor: Offset(0.5, 0.5), // Center the marker
          flat: true, // Keep marker flat (not tilted)
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    }

    // Add pickup location marker
    if (_pickupLocation != null && _pickupMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('pickup_location'),
          position: _pickupLocation!,
          icon: _pickupMarkerIcon!,
          anchor: Offset(0.5, 0.5), // Center the marker
          flat: true, // Keep marker flat (not tilted)
          infoWindow: InfoWindow(
            title: 'Pickup Location',
            snippet: widget.isPickupSelection
                ? 'Tap to remove'
                : 'Selected pickup point',
          ),
          onTap: () => _removePickupLocation(),
        ),
      );
    }

    // Add bus marker if tracking
    if (_busLocation != null && _busMarkerIcon != null && _bookedBus != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('bus_location'),
          position: _busLocation!,
          icon: _busMarkerIcon!,
          anchor: Offset(0.5, 0.5), // Center the marker
          flat: true, // Keep marker flat (not tilted)
          infoWindow: InfoWindow(
            title: 'Your Bus',
            snippet: '${_bookedBus!.numberPlate} • ETA: $_estimatedArrival',
          ),
        ),
      );
    }
  }

  // Remove pickup location
  void _removePickupLocation() async {
    setState(() {
      _pickupLocation = null;
    });
    _updateMarkers();

    // Deactivate pickup location in Firestore
    try {
      final userId = _getCurrentUserId();
      if (userId != null) {
        final existingLocations = await FirebaseFirestore.instance
            .collection('pickup_locations')
            .where('userId', isEqualTo: userId)
            .where('isActive', isEqualTo: true)
            .get();

        // Deactivate all active pickup locations
        for (var doc in existingLocations.docs) {
          await doc.reference.update({'isActive': false});
        }
      }
    } catch (e) {
      print('Error removing pickup location: $e');
    }

    _showSnackBar('Pickup location removed');
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

  // Load saved pickup locations
  Future<void> _loadSavedPickupLocations() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) return;

      // Try to load the most recent active pickup location
      final snapshot = await FirebaseFirestore.instance
          .collection('pickup_locations')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final locationData = snapshot.docs.first.data();
        final latitude = locationData['latitude'] as double;
        final longitude = locationData['longitude'] as double;
        setState(() {
          _pickupLocation = LatLng(latitude, longitude);
        });
        _updateMarkers();
        print('Loaded saved pickup location from pickup_locations');
        // Always show route in pickup selection mode
        if (widget.isPickupSelection && _bookedBus != null) {
          // Fetch original route (start to destination)
          await _fetchOriginalRoutePolyline();
          
          // Fetch pickup route
          final startLat = _bookedBus!.startLat ?? 0.0;
          final startLng = _bookedBus!.startLng ?? 0.0;
          await _fetchRoutePolyline(
            LatLng(startLat, startLng),
            LatLng(latitude, longitude),
          );
        }
      } else {
        // Fallback: Try to load from the latest booking
        final bookingSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'confirmed')
            .orderBy('departureDate', descending: true)
            .limit(1)
            .get();
        if (bookingSnapshot.docs.isNotEmpty) {
          final bookingData = bookingSnapshot.docs.first.data();
          if (bookingData['pickupLocation'] != null) {
            final pickup = bookingData['pickupLocation'];
            setState(() {
              _pickupLocation = LatLng(pickup['latitude'], pickup['longitude']);
            });
            _updateMarkers();
            print('Loaded pickup location from latest booking');
            // Always show route in pickup selection mode
            if (widget.isPickupSelection && _bookedBus != null) {
              // Fetch original route (start to destination)
              await _fetchOriginalRoutePolyline();
              
              // Fetch pickup route
              final startLat = _bookedBus!.startLat ?? 0.0;
              final startLng = _bookedBus!.startLng ?? 0.0;
              await _fetchRoutePolyline(
                LatLng(startLat, startLng),
                LatLng(pickup['latitude'], pickup['longitude']),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error loading saved pickup locations: $e');
    }
  }

  // Navigate to booking screen
  void _navigateToBooking() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FindBusScreen()),
    );
  }

  // Confirm pickup location and return to booking screen
  void _confirmPickupLocation() async {
    if (_pickupLocation == null) {
      _showSnackBar('Please select a pickup location first');
      return;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
      );

      String address = 'Selected Location';
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final name = placemark.name ?? '';
        final street = placemark.street ?? '';
        final locality = placemark.locality ?? '';
        final country = placemark.country ?? '';
        address = [
          name,
          street,
          locality,
          country,
        ].where((part) => part.isNotEmpty).join(', ');
        if (address.isEmpty) address = 'Selected Location';
      }

      Navigator.pop(context, {'location': _pickupLocation, 'address': address});
    } catch (e) {
      print('Error getting address: $e');
      Navigator.pop(context, {
        'location': _pickupLocation,
        'address': 'Selected Location',
      });
    }
  }

  String formatDate(DateTime date) {
    final daySuffix = _getDayOfMonthSuffix(date.day);
    final formatted =
        DateFormat('EEEE d').format(date) +
        daySuffix +
        DateFormat(' MMMM, yyyy').format(date);
    return formatted;
  }

  String _getDayOfMonthSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _getCurrentLocation();
    _checkActiveBooking();
    _loadSavedPickupLocations();
    // If in pickup selection mode and bus is known, show route from start to destination
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.isPickupSelection && _bookedBus != null) {
        // Fetch original route (start to destination)
        await _fetchOriginalRoutePolyline();
        
        // Fetch pickup route if pickup is selected
        if (_pickupLocation != null) {
          final startLat = _bookedBus!.startLat ?? 0.0;
          final startLng = _bookedBus!.startLng ?? 0.0;
          await _fetchRoutePolyline(
            LatLng(startLat, startLng),
            _pickupLocation!,
          );
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen becomes active (e.g., when returning from seat selection)
    _refreshScreenData();
  }

  // Refresh all screen data
  Future<void> _refreshScreenData() async {
    await _checkActiveBooking();
    await _loadSavedPickupLocations();
    _updateMarkers();
  }

  @override
  void dispose() {
    // Cancel bus tracking timer
    _busTrackingTimer?.cancel();

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
          widget.isPickupSelection ? 'Select Pickup Location' : 'Passenger Map',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF576238),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.isPickupSelection && _pickupLocation != null)
            TextButton(
              onPressed: _confirmPickupLocation,
              child: Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshScreenData,
        child: Column(
          children: [
            // Bus tracking info card (only show if has active booking)
            if (_hasActiveBooking && _bookedBus != null)
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
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Bus is on the way!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                _bookedBus!.numberPlate,
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
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'ETA: $_estimatedArrival',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.route, size: 16, color: Color(0xFF6B7280)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_bookedBus!.startPoint} → ${_bookedBus!.destination}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Pickup location info card (only show if has saved pickup location and no active booking)
            if (!_hasActiveBooking &&
                _pickupLocation != null &&
                !widget.isPickupSelection)
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
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
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
                            'Saved Pickup Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Your previously saved pickup point',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _removePickupLocation,
                      icon: Icon(Icons.close, color: Colors.red),
                      tooltip: 'Remove pickup location',
                    ),
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
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        // Draw the route polyline if available
                        polylines: {
                          // Original route (start to destination) - always show in pickup selection
                          if (_originalRouteInfo != null &&
                              widget.isPickupSelection)
                            Polyline(
                              polylineId: PolylineId('original_route'),
                              color: Colors.blue,
                              width: 4,
                              points: _originalRouteInfo!.polylinePoints
                                  .map((e) => LatLng(e.latitude, e.longitude))
                                  .toList(),
                            ),
                          // Pickup route (start to pickup) or bus tracking route
                          if (_routeInfo != null)
                            Polyline(
                              polylineId: PolylineId('route'),
                              color: widget.isPickupSelection
                                  ? Colors.green
                                  : Colors.blue,
                              width: 5,
                              points: _routeInfo!.polylinePoints
                                  .map((e) => LatLng(e.latitude, e.longitude))
                                  .toList(),
                            ),
                        },
                        onTap: (LatLng latLng) async {
                          if (widget.isPickupSelection) {
                            await _addPickupLocation(latLng);
                            // Fetch original route (start to destination) if not already fetched
                            if (_originalRouteInfo == null) {
                              await _fetchOriginalRoutePolyline();
                            }
                            // Fetch route from bus start to pickup
                            if (_bookedBus != null) {
                              final startLat = _bookedBus!.startLat ?? 0.0;
                              final startLng = _bookedBus!.startLng ?? 0.0;
                              await _fetchRoutePolyline(
                                LatLng(startLat, startLng),
                                latLng,
                              );
                            }
                          }
                        },
                      ),
                      if (_isLoadingRoute)
                        const Center(child: CircularProgressIndicator()),
                      // Zoom controls
                      MapZoomControls(mapController: _mapController),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom action bar
            Container(
              margin: EdgeInsets.all(16),
              child: Row(
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
                                valueColor: AlwaysStoppedAnimation<Color>(
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
                  if (!widget.isPickupSelection) ...[
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToBooking,
                        icon: Icon(Icons.directions_bus),
                        label: Text('Book Bus'),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
