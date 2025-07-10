import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';

class BusDriverHomeScreen extends StatefulWidget {
  @override
  _BusDriverHomeScreenState createState() => _BusDriverHomeScreenState();
}

class _BusDriverHomeScreenState extends State<BusDriverHomeScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isOnline = false;
  bool _isLoading = true;
  String _driverName = 'Loading...';
  String _busNumber = 'N/A';
  String _assignedRoute = 'No route assigned';
  String _lastUpdated = 'Never';
  List<Map<String, dynamic>> _notifications = [];

  // Sample route data - replace with actual data from your backend
  final List<LatLng> _routePoints = [
    LatLng(37.7749, -122.4194),
    LatLng(37.7849, -122.4094),
    LatLng(37.7949, -122.3994),
  ];

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeDriver();
    // Location is now manual only - use the location button when needed
    _loadNotifications();
  }

  Future<void> _initializeDriver() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final driverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (driverDoc.exists) {
          final data = driverDoc.data() as Map<String, dynamic>;
          setState(() {
            _driverName = data['name'] ?? 'Unknown Driver';
            _busNumber = data['busNumber'] ?? 'N/A';
            _assignedRoute = data['assignedRoute'] ?? 'No route assigned';
            _isOnline = data['isOnline'] ?? false;
            _lastUpdated = data['lastUpdated'] != null
                ? DateFormat(
                    'MMM dd, yyyy HH:mm',
                  ).format((data['lastUpdated'] as Timestamp).toDate())
                : 'Never';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading driver data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _markers.clear();
        _markers.add(
          Marker(
            markerId: MarkerId('driver_location'),
            position: LatLng(position.latitude, position.longitude),
            icon: MarkerIcons.driverMarker,
            infoWindow: InfoWindow(
              title: 'Your Location',
              snippet: 'Bus: $_busNumber',
            ),
          ),
        );
        _addRouteMarkers();
        _addRoutePolyline();
      });

      await _updateLocationInFirestore(position);
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  void _addRouteMarkers() {
    for (int i = 0; i < _routePoints.length; i++) {
      _markers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: _routePoints[i],
          icon: MarkerIcons.startMarker, // Using start marker for route stops
          infoWindow: InfoWindow(
            title: 'Stop ${i + 1}',
            snippet: 'Route: $_assignedRoute',
          ),
        ),
      );
    }
  }

  void _addRoutePolyline() {
    if (_routePoints.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          points: _routePoints,
          color: Colors.blue,
          width: 3,
        ),
      );
    }
  }

  Future<void> _updateLocationInFirestore(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'currentLocation': {
                'latitude': position.latitude,
                'longitude': position.longitude,
              },
              'lastUpdated': FieldValue.serverTimestamp(),
            });

        setState(() {
          _lastUpdated = DateFormat(
            'MMM dd, yyyy HH:mm',
          ).format(DateTime.now());
        });
      }
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  Future<void> _toggleOnlineStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'isOnline': !_isOnline,
              'lastUpdated': FieldValue.serverTimestamp(),
            });

        setState(() {
          _isOnline = !_isOnline;
          _lastUpdated = DateFormat(
            'MMM dd, yyyy HH:mm',
          ).format(DateTime.now());
        });
      }
    } catch (e) {
      print('Error toggling status: $e');
    }
  }

  Future<void> _loadNotifications() async {
    // Sample notifications - replace with actual data from your backend
    setState(() {
      _notifications = [
        {
          'id': '1',
          'title': 'Route Change',
          'message': 'Your route has been updated for tomorrow',
          'timestamp': DateTime.now().subtract(Duration(hours: 2)),
          'type': 'warning',
        },
        {
          'id': '2',
          'title': 'Maintenance Alert',
          'message': 'Bus inspection scheduled for next week',
          'timestamp': DateTime.now().subtract(Duration(days: 1)),
          'type': 'info',
        },
      ];
    });
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notifications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ..._notifications
                .map(
                  (notification) => Card(
                    child: ListTile(
                      leading: Icon(
                        notification['type'] == 'warning'
                            ? Icons.warning_amber
                            : Icons.info_outline,
                        color: notification['type'] == 'warning'
                            ? Colors.orange
                            : Colors.blue,
                      ),
                      title: Text(notification['title']),
                      subtitle: Text(notification['message']),
                      trailing: Text(
                        DateFormat(
                          'MMM dd, HH:mm',
                        ).format(notification['timestamp']),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Emergency Support'),
        content: Text('Are you sure you want to contact emergency support?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement emergency contact functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Emergency support contacted')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.blue[100],
                    backgroundImage:
                        null, // Replace with NetworkImage or FileImage if you have a profile pic
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: Colors.blue[600],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: InkWell(
                      onTap: () {
                        // TODO: Implement image picker for profile pic
                      },
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.camera_alt,
                          size: 18,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _driverName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.badge),
                title: const Text('NIN Number'),
                subtitle: Text('CF1234567890'), // Replace with actual NIN
              ),
              ListTile(
                leading: const Icon(Icons.phone),
                title: const Text('Contact'),
                subtitle: Text(
                  '+256 700 000000',
                ), // Replace with actual contact
              ),
              ListTile(
                leading: const Icon(Icons.email),
                title: const Text('Email'),
                subtitle: Text('driver@email.com'), // Replace with actual email
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: () async {
                  Navigator.of(context).pop(); // Close the modal
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/signin');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditableProfileDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _driverName,
    );
    final TextEditingController ninController = TextEditingController(
      text: 'CF1234567890',
    ); // Replace with actual NIN
    final TextEditingController contactController = TextEditingController(
      text: '+256 700 000000',
    ); // Replace with actual contact
    final TextEditingController emailController = TextEditingController(
      text: 'driver@email.com',
    ); // Replace with actual email

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.blue[100],
                      backgroundImage: null, // Add image logic if needed
                      child: Icon(
                        Icons.person,
                        size: 48,
                        color: Colors.blue[600],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 4,
                      child: InkWell(
                        onTap: () {
                          // TODO: Implement image picker for profile pic
                        },
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ninController,
                  decoration: const InputDecoration(
                    labelText: 'NIN Number',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _driverName = nameController.text;
                      // Save NIN, contact, and email to backend if needed
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated!')),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Dashboard'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: _showProfileDialog,
          ),
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.notifications),
                if (_notifications.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text(
                        '${_notifications.length}',
                        style: TextStyle(color: Colors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showNotifications,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Driver Information Card
            Container(
              margin: EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.blue[100],
                            child: Icon(
                              Icons.person,
                              size: 35,
                              color: Colors.blue[600],
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
                                SizedBox(height: 4),
                                Text(
                                  'Bus: $_busNumber',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Text(
                                  'Route: $_assignedRoute',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Last updated: $_lastUpdated',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Status: ',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Chip(
                                label: Text(_isOnline ? 'Online' : 'Offline'),
                                backgroundColor: _isOnline
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                labelStyle: TextStyle(
                                  color: _isOnline ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOnline,
                            onChanged: (value) => _toggleOnlineStatus(),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Live Map Section
            Container(
              margin: EdgeInsets.all(16),
              height: 300,
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
                child: Stack(
                  children: [
                    _currentPosition != null
                        ? GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              zoom: 15,
                            ),
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                            },
                            markers: _markers,
                            polylines: _polylines,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                          )
                        : Center(child: CircularProgressIndicator()),
                    // Zoom controls
                    if (_currentPosition != null)
                      MapZoomControls(mapController: _mapController),
                  ],
                ),
              ),
            ),

            // Quick Actions Grid
            Container(
              margin: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _buildActionCard(
                        icon: Icons.location_on,
                        title: 'Update Location',
                        color: Colors.blue,
                        onTap: _getCurrentLocation,
                      ),
                      _buildActionCard(
                        icon: Icons.route,
                        title: 'View Route',
                        color: Colors.green,
                        onTap: () {
                          // Navigate to route details
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Route details coming soon'),
                            ),
                          );
                        },
                      ),
                      _buildActionCard(
                        icon: Icons.history,
                        title: 'Trip History',
                        color: Colors.orange,
                        onTap: () {
                          // Navigate to trip history
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Trip history coming soon')),
                          );
                        },
                      ),
                      _buildActionCard(
                        icon: Icons.emergency,
                        title: 'Emergency',
                        color: Colors.red,
                        onTap: _showEmergencyDialog,
                      ),
                      _buildActionCard(
                        icon: Icons.support_agent,
                        title: 'Support',
                        color: Colors.purple,
                        onTap: () {
                          // Navigate to support
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Support chat coming soon')),
                          );
                        },
                      ),
                      _buildActionCard(
                        icon: Icons.person,
                        title: 'Profile',
                        color: Colors.teal,
                        onTap:
                            _showEditableProfileDialog, // <-- call the new method
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
