import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';

const kGoogleApiKey = 'AIzaSyC2n6urW_4DUphPLUDaNGAW_VN53j0RP4s';

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;

  static final CameraPosition _initialPosition = CameraPosition(
    target:
        LatLng(0.34540783865964797, 32.54297125499706), // Kampala coordinates
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
  Set<Marker> _searchMarkers = {};
  final Mode _mode = Mode.overlay;

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
      _busMarkerIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      _userMarkerIcon =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
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
              snippet:
                  '${bus['startPoint'] ?? 'Unknown'} → ${bus['destination'] ?? 'Unknown'}',
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
            Text(
                'Route: ${bus['startPoint'] ?? 'Unknown'} → ${bus['destination'] ?? 'Unknown'}'),
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

  Future<void> _handleSearchButton() async {
    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      mode: _mode,
      language: 'en',
      strictbounds: false,
      types: [""],
      decoration: InputDecoration(
        hintText: 'Search',
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
      components: [Component(Component.country, "ug")],
    );
    if (p != null) {
      await _displayPrediction(p);
    }
  }

  Future<void> _displayPrediction(Prediction p) async {
    GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
    PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);
    final lat = detail.result.geometry!.location.lat;
    final lng = detail.result.geometry!.location.lng;
    _searchMarkers.clear();
    _searchMarkers.add(Marker(
      markerId: const MarkerId("search_result"),
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: detail.result.name),
    ));
    setState(() {});
    final controller = _mapController ?? await _controller.future;
    controller
        .animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.0));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _mapController = controller;
            },
            initialCameraPosition: _initialPosition,
            markers: _allMarkers.union(_searchMarkers),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),
          // Search field overlay
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(24),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for places...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) async {
                  if (value.isNotEmpty) {
                    Prediction? p = await PlacesAutocomplete.show(
                      context: context,
                      apiKey: kGoogleApiKey,
                      mode: _mode,
                      language: 'en',
                      strictbounds: false,
                      types: [""],
                      decoration: InputDecoration(
                        hintText: 'Search',
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                      components: [Component(Component.country, "ug")],
                    );
                    if (p != null) {
                      await _displayPrediction(p);
                    }
                  }
                },
              ),
            ),
          ),
          // My location button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'location',
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              child: _isLoadingLocation
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
