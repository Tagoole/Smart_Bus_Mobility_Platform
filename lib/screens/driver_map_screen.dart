import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:smart_bus_mobility_platform1/resources/bus_service.dart';
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
    target:
        LatLng(0.34540783865964797, 32.54297125499706), // Kampala coordinates
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
            'role': userData['role'],
          });
        }
      }

      setState(() {
        _passengers = passengers;
        _isLoading = false;
      });

      _updateMarkers();
    } catch (e) {
      print('Error loading passengers: $e');
      setState(() {
        _isLoading = false;
      });
    }
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

    // Add passenger markers
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
          final icon = _passengerMarkerIcon ?? BitmapDescriptor.defaultMarker;

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

  // Navigate to passenger
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

  @override
  void dispose() {
    _passengerRefreshTimer?.cancel();
    _mapController?.dispose();
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
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
            )
          : Stack(
              children: [
                // Full screen map
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
                  onTap: (LatLng location) {
                    // Handle map tap if needed
                  },
                ),

                if (_isLoadingLocation)
                  const Center(child: CircularProgressIndicator()),

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
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.people, color: Colors.white),
                      onPressed: _showPassengerList,
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
                              child: Icon(Icons.person, color: Colors.blue),
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
                            trailing: Column(
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
