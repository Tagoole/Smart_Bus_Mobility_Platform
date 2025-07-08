import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_map_screen.dart';
import 'dart:async';

class BusDriverHomeScreen extends StatefulWidget {
  const BusDriverHomeScreen({super.key});

  @override
  State<BusDriverHomeScreen> createState() => _BusDriverHomeScreenState();
}

class _BusDriverHomeScreenState extends State<BusDriverHomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Driver state
  bool _isOnline = false;
  final String _currentRoute = 'No route assigned';
  String _driverName = 'Driver';
  final String _busNumber = 'N/A';

  // Location tracking
  LatLng? _currentLocation;
  GoogleMapController? _mapController;
  Timer? _locationUpdateTimer;
  String? _busId; // Set this to the current bus's Firestore document ID

  @override
  void initState() {
    super.initState();
    _loadDriverData();
    _getCurrentLocation();
    // Optionally, set _busId here or after driver assignment
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _updateBusLocationInFirestore();
    });
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
  }

  Future<void> _updateBusLocationInFirestore() async {
    if (_busId == null || _currentLocation == null) return;
    await _firestore.collection('buses').doc(_busId).update({
      'currentLocation': {
        'latitude': _currentLocation!.latitude,
        'longitude': _currentLocation!.longitude,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _loadDriverData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _driverName = userData['username'] ?? 'Driver';
          });
        }
      }
    } catch (e) {
      print('Error loading driver data: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentLocation!, zoom: 15),
          ),
        );
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _toggleOnlineStatus() {
    setState(() {
      _isOnline = !_isOnline;
    });
    _updateDriverStatus();
    if (_isOnline) {
      _startLocationUpdates();
    } else {
      _stopLocationUpdates();
    }
  }

  Future<void> _updateDriverStatus() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('drivers').doc(user.uid).set({
          'isOnline': _isOnline,
          'currentLocation': _currentLocation != null
              ? {
                  'latitude': _currentLocation!.latitude,
                  'longitude': _currentLocation!.longitude,
                }
              : null,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error updating driver status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Dashboard'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _auth.signOut();
            },
          ),
        ],
      ),
      body: Column(
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
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue[100],
                      child: Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _driverName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Bus: $_busNumber',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          Text(
                            'Route: $_currentRoute',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isOnline,
                      onChanged: (value) => _toggleOnlineStatus(),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusChip(
                      'Online',
                      _isOnline ? Colors.green : Colors.grey,
                      Icons.circle,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Map Section
          Expanded(
            flex: 2,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _currentLocation != null
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _currentLocation!,
                          zoom: 15,
                        ),
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                        markers: {
                          Marker(
                            markerId: MarkerId('driver_location'),
                            position: _currentLocation!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueBlue,
                            ),
                            infoWindow: InfoWindow(
                              title: 'Your Location',
                              snippet: 'Driver position',
                            ),
                          ),
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                      )
                    : Center(child: CircularProgressIndicator()),
              ),
            ),
          ),

          // Quick Actions
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionButton(
                  Icons.location_on,
                  'Update Location',
                  Colors.blue,
                  _getCurrentLocation,
                ),
                _buildQuickActionButton(
                  Icons.map,
                  'Passenger Map',
                  Colors.orange,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DriverMapScreen()),
                  ),
                ),
                _buildQuickActionButton(
                  Icons.history,
                  'Trip History',
                  Colors.purple,
                  () => _showSnackBar('Trip history feature coming soon!'),
                ),
                _buildQuickActionButton(
                  Icons.support_agent,
                  'Support',
                  Colors.teal,
                  () => _showSnackBar('Support feature coming soon!'),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        child: Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color),
          ),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }
}
