import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;
  
  static final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0.34540783865964797, 32.54297125499706), // Kampala coordinates
    zoom: 14,
  );

  // Location tracking
  LatLng? _currentLocation;
  BitmapDescriptor? _busMarkerIcon;
  BitmapDescriptor? _userMarkerIcon;
  bool _isLoadingLocation = false;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Bus data
  List<Map<String, dynamic>> _availableBuses = [];
  final Set<Marker> _allMarkers = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _loadMarkerIcons();
    await _getCurrentLocation();
    await _loadAvailableBuses();
  }

  Future<void> _loadMarkerIcons() async {
    try {
      _busMarkerIcon = await MarkerIcons.busIcon;
      _userMarkerIcon = await MarkerIcons.passengerIcon;
    } catch (e) {
      print('Error loading marker icons: $e');
      // Fallback to default markers
      _busMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _userMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

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

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Update camera to current location
      if (_controller.isCompleted) {
        GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentLocation!, zoom: 15),
          ),
        );
      }

      _updateMarkers();
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
      // Set default location as fallback
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _currentLocation = LatLng(0.34540783865964797, 32.54297125499706);
    });
  }

  Future<void> _loadAvailableBuses() async {
    try {
      final busesSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('isAvailable', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> buses = [];
      for (var doc in busesSnapshot.docs) {
        final busData = doc.data();
        buses.add({
          'busId': doc.id,
          ...busData,
        });
      }

      setState(() {
        _availableBuses = buses;
      });

      _updateMarkers();
    } catch (e) {
      print('Error loading available buses: $e');
    }
  }

  void _updateMarkers() {
    _allMarkers.clear();

    // Add current location marker
    if (_currentLocation != null && _userMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('current_location'),
          position: _currentLocation!,
          icon: _userMarkerIcon!,
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    }

    // Add bus markers
    for (int i = 0; i < _availableBuses.length; i++) {
      final bus = _availableBuses[i];
      if (bus['currentLocation'] != null && _busMarkerIcon != null) {
        final location = bus['currentLocation'];
        final latLng = LatLng(location['latitude'], location['longitude']);

        _allMarkers.add(
          Marker(
            markerId: MarkerId('bus_${bus['busId']}'),
            position: latLng,
            icon: _busMarkerIcon!,
            infoWindow: InfoWindow(
              title: 'Bus ${bus['numberPlate'] ?? 'Unknown'}',
              snippet: '${bus['startPoint'] ?? 'Unknown'} → ${bus['destination'] ?? 'Unknown'}',
            ),
            onTap: () => _showBusDetails(bus),
          ),
        );
      }
    }

    setState(() {});
  }

  void _showBusDetails(Map<String, dynamic> bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bus Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plate: ${bus['numberPlate'] ?? 'Unknown'}'),
            SizedBox(height: 8),
            Text('Route: ${bus['startPoint'] ?? 'Unknown'} → ${bus['destination'] ?? 'Unknown'}'),
            SizedBox(height: 8),
            Text('Driver: ${bus['driverName'] ?? 'Unknown'}'),
            SizedBox(height: 8),
            Text('Available Seats: ${bus['availableSeats'] ?? 'Unknown'}'),
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
              _bookBus(bus);
            },
            child: Text('Book This Bus'),
          ),
        ],
      ),
    );
  }

  void _bookBus(Map<String, dynamic> bus) {
    // TODO: Implement booking functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Booking functionality coming soon!')),
    );
  }

  // Search functionality
  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // TODO: Implement actual search logic
      // For now, just filter buses by route
      final filteredBuses = _availableBuses.where((bus) {
        final startPoint = bus['startPoint']?.toString().toLowerCase() ?? '';
        final destination = bus['destination']?.toString().toLowerCase() ?? '';
        final queryLower = query.toLowerCase();
        
        return startPoint.contains(queryLower) || 
               destination.contains(queryLower);
      }).toList();

      setState(() {
        _searchResults = filteredBuses;
        _isSearching = false;
      });
    } catch (e) {
      print('Error performing search: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Passenger Map'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for routes, destinations...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _isSearching 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _performSearch,
            ),
          ),

          // Search results
          if (_searchResults.isNotEmpty)
            Container(
              height: 200,
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final bus = _searchResults[index];
                  return ListTile(
                    leading: Icon(Icons.directions_bus, color: Colors.green),
                    title: Text('${bus['startPoint']} → ${bus['destination']}'),
                    subtitle: Text('Bus: ${bus['numberPlate']}'),
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                      });
                      _showBusDetails(bus);
                    },
                  );
                },
              ),
            ),

          // Map
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
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
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    if (_isLoadingLocation)
                      Center(child: CircularProgressIndicator()),
                    
                    // My location button
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                        child: _isLoadingLocation
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.my_location),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
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
