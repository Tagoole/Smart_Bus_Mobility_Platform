import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
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

class DriverMapScreen extends StatefulWidget {
  const DriverMapScreen({super.key});

  @override
  State<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends State<DriverMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
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
  final Set<Polyline> _allPolylines = {};

  // UI state
  bool _isLoading = true;
  String _statusMessage = 'Loading...';

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

  Future<void> _loadMarkerIcons() async {
    try {
      // Load driver marker icon
      final Uint8List driverIconData = await getImagesFromMarkers(
        'images/bus_icon.png',
        60,
      );
      _driverMarkerIcon = BitmapDescriptor.fromBytes(driverIconData);

      // Load passenger marker icon
      final Uint8List passengerIconData = await getImagesFromMarkers(
        'images/passenger_icon.png',
        50,
      );
      _passengerMarkerIcon = BitmapDescriptor.fromBytes(passengerIconData);
    } catch (e) {
      print('Error loading marker icons: $e');
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
        setState(() {
          _statusMessage = 'No bus assigned to you';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading driver data: $e');
      setState(() {
        _statusMessage = 'Error loading driver data';
        _isLoading = false;
      });
    }
  }

  // Load passengers who have booked this driver's bus
  Future<void> _loadPassengers() async {
    if (_driverBus == null) return;

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
      await _drawAllPassengerPolylines();
    } catch (e) {
      print('Error loading passengers: $e');
      setState(() {
        _statusMessage = 'Error loading passengers';
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

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      );

      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
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
      await _drawAllPassengerPolylines();
    } catch (e) {
      print('Error getting location: $e');
      _showSnackBar('Error getting your location. Please try again.');
      setState(() {
        _isLoadingLocation = false;
      });
    }
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
          infoWindow: InfoWindow(
            title: 'Your Location',
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
            infoWindow: InfoWindow(
              title: passenger['userName'],
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

  // Add this function to fetch route polyline from Google Directions API
  Future<List<LatLng>> _getRoutePolyline(LatLng start, LatLng end) async {
    final apiKey = 'AIzaSyC2n6urW_4DUphPLUDaNGAW_VN53j0RP4s'; // <-- Replace with your API key
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final points = data['routes'][0]['overview_polyline']['points'];
      return _decodePolyline(points);
    } else {
      throw Exception('Failed to fetch directions');
    }
  }

  // Polyline decoder
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

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
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
        try {
          final polylinePoints = await _getRoutePolyline(
            _driverLocation!,
            passengerLatLng,
          );
          polylines.add(
            Polyline(
              polylineId: PolylineId('route_to_passenger_${polylineId++}'),
              points: polylinePoints,
              color: Colors.blue,
              width: 5,
            ),
          );
        } catch (e) {
          print('Error fetching polyline for passenger: $e');
        }
      }
    }
    setState(() {
      _allPolylines.clear();
      _allPolylines.addAll(polylines);
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
    });
    await _loadDriverData();
    await _getCurrentLocation();
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

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _loadDriverData();
    _getCurrentLocation();

    // Set up periodic refresh for passengers
    Timer.periodic(Duration(minutes: 2), (timer) {
      if (mounted) {
        _loadPassengers();
      }
    });

    // Set up frequent location updates for real-time tracking
    Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted && _isOnline) {
        _getCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
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
                        onTap: (LatLng location) {
                          // Handle map tap if needed
                        },
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
