import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/location_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:smart_bus_mobility_platform1/screens/booking_screen.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  final Set<Polyline> _allPolylines = {};

  // Bus tracking variables
  BusModel? _bookedBus;
  LatLng? _busLocation;
  String _estimatedArrival = 'Calculating...';
  bool _hasActiveBooking = false;
  Timer? _busTrackingTimer;

  // Load custom marker icons
  Future<Uint8List> getImagesFromMarkers(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetHeight: width,
    );
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return (await frameInfo.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }

  // Load custom marker icons
  Future<void> _loadMarkerIcons() async {
    try {
      // Load pickup marker icon
      final Uint8List pickupIconData = await getImagesFromMarkers(
        'images/passenger_icon.png',
        60,
      );
      _pickupMarkerIcon = BitmapDescriptor.fromBytes(pickupIconData);

      // Load bus marker icon
      final Uint8List busIconData = await getImagesFromMarkers(
        'images/bus_icon.png',
        70,
      );
      _busMarkerIcon = BitmapDescriptor.fromBytes(busIconData);
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
      // Get driver's current location from Firestore
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_bookedBus!.driverId)
          .get();

      if (driverDoc.exists) {
        final driverData = driverDoc.data()!;
        if (driverData['currentLocation'] != null) {
          final location = driverData['currentLocation'];
          final newBusLocation = LatLng(
            location['latitude'],
            location['longitude'],
          );

          setState(() {
            _busLocation = newBusLocation;
          });

          // Calculate ETA and route
          await _calculateETAAndRoute();
          _updateMarkers();
        }
      }
    } catch (e) {
      print('Error updating bus location: $e');
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
        _estimatedArrival = '${estimatedMinutes} min';
      });

      // Generate route polyline (simplified for demo)
      _generateRoutePolyline();
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

  // Generate route polyline (simplified)
  void _generateRoutePolyline() {
    if (_busLocation == null || _pickupLocation == null) return;

    // Create a simple straight line for demo
    // In production, you would use Google Directions API to get the actual route
    final List<LatLng> routePoints = [_busLocation!, _pickupLocation!];

    _allPolylines.clear();
    _allPolylines.add(
      Polyline(
        polylineId: PolylineId('bus_route'),
        points: routePoints,
        color: Colors.blue,
        width: 4,
        geodesic: true,
      ),
    );
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

      // Create location model
      final locationModel = LocationModel.createPickupLocation(
        userId: userId,
        latitude: location.latitude,
        longitude: location.longitude,
        locationName: 'Pickup Location',
        notes: 'Added on ${DateTime.now().toString()}',
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
          infoWindow: InfoWindow(
            title: 'Your Bus',
            snippet: '${_bookedBus!.numberPlate} • ETA: $_estimatedArrival',
          ),
        ),
      );
    }
  }

  // Remove pickup location
  void _removePickupLocation() {
    setState(() {
      _pickupLocation = null;
    });
    _updateMarkers();
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
    // Don't load saved locations if in pickup selection mode
    if (widget.isPickupSelection) return;

    try {
      final userId = _getCurrentUserId();
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('pickup_locations')
          .where('userId', isEqualTo: userId)
          .where('locationType', isEqualTo: 'pickup')
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1) // Get the most recent pickup location
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final locationData = doc.data();
        final locationModel = LocationModel.fromJson(locationData, doc.id);

        setState(() {
          _pickupLocation = LatLng(
            locationModel.latitude,
            locationModel.longitude,
          );
        });
        _updateMarkers();
        print('Loaded saved pickup location: ${locationModel.locationName}');
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
      // Get address for the selected location
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
      );

      String address = 'Selected Location';
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        address =
            '${placemark.name ?? placemark.street ?? placemark.locality ?? ''}, ${placemark.country ?? ''}'
                .trim();
        if (address.endsWith(',')) {
          address = address.substring(0, address.length - 1);
        }
      }

      // Return the selected location to the booking screen
      Navigator.pop(context, {'location': _pickupLocation, 'address': address});
    } catch (e) {
      print('Error getting address: $e');
      // Return with just coordinates if address lookup fails
      Navigator.pop(context, {
        'location': _pickupLocation,
        'address': 'Selected Location',
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _getCurrentLocation();
    _loadSavedPickupLocations();
    _checkActiveBooking();
  }

  @override
  void dispose() {
    _busTrackingTimer?.cancel();
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
      body: Column(
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
                child: GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  initialCameraPosition: _initialPosition,
                  markers: _allMarkers,
                  polylines: _allPolylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  onTap: widget.isPickupSelection ? _addPickupLocation : null,
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
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
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
    );
  }
}
