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
import 'package:smart_bus_mobility_platform1/models/location_model.dart';
import 'package:geocoding/geocoding.dart';

// return user info so tha checking role is ok

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

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
  bool _isLoadingLocation = false;
  final Set<Marker> _allMarkers = {};

  // Variables for search functionality
  final TextEditingController _searchController = TextEditingController();
  List<Placemark> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  // Load custom pickup marker icon
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

  // Load custom pickup marker icon
  Future<void> _loadPickupMarkerIcon() async {
    try {
      final Uint8List iconData = await getImagesFromMarkers(
        'images/passenger_icon.png',
        60,
      );
      _pickupMarkerIcon = BitmapDescriptor.fromBytes(iconData);
    } catch (e) {
      print('Error loading pickup marker icon: $e');
      _pickupMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
    }
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

    // Save pickup location to Firestore
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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
            snippet: 'Tap to remove',
          ),
          onTap: () => _removePickupLocation(),
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

  // Search for places
  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      
      if (locations.isNotEmpty) {
        // Get placemarks for more detailed information
        List<Placemark> placemarks = await placemarkFromCoordinates(
          locations.first.latitude,
          locations.first.longitude,
        );

        setState(() {
          _searchResults = placemarks;
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults.clear();
          _isSearching = false;
        });
        _showSnackBar('No places found for "$query"');
      }
    } catch (e) {
      print('Error searching places: $e');
      setState(() {
        _isSearching = false;
      });
      _showSnackBar('Error searching for places. Please try again.');
    }
  }

  // Select a search result
  void _selectSearchResult(Placemark placemark) async {
    try {
      // Get coordinates for the selected place
      List<Location> locations = await locationFromAddress(
        '${placemark.street}, ${placemark.locality}, ${placemark.country}',
      );

      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);

        // Add as pickup location
        await _addPickupLocation(latLng);

        // Move camera to the selected location
        if (_controller.isCompleted) {
          GoogleMapController controller = await _controller.future;
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: latLng, zoom: 16),
            ),
          );
        }

        // Clear search
        setState(() {
          _searchController.clear();
          _searchResults.clear();
          _showSearchResults = false;
        });

        _showSnackBar('Pickup location added: ${placemark.name ?? placemark.street}');
      }
    } catch (e) {
      print('Error selecting search result: $e');
      _showSnackBar('Error adding location. Please try again.');
    }
  }

  // Clear search
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults.clear();
      _showSearchResults = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPickupMarkerIcon();
    _getCurrentLocation();
    _loadSavedPickupLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _initialPosition,
              mapType: MapType.normal,
              markers: _allMarkers,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              onTap: (LatLng location) {
                // Add pickup location when user taps on map
                _addPickupLocation(location);
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
            ),

            // Top app bar with search functionality
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Search bar
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Colors.grey[600]),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search for a place...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey[500]),
                            ),
                            onChanged: (value) {
                              if (value.length > 2) {
                                _searchPlaces(value);
                              } else {
                                setState(() {
                                  _searchResults.clear();
                                  _showSearchResults = false;
                                });
                              }
                            },
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty) {
                                _searchPlaces(value);
                              }
                            },
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: _clearSearch,
                            tooltip: 'Clear search',
                          ),
                        if (_pickupLocation != null)
                          IconButton(
                            icon: Icon(Icons.clear, color: Colors.red),
                            onPressed: _removePickupLocation,
                            tooltip: 'Remove pickup location',
                          ),
                      ],
                    ),
                  ),
                  
                  // Search results
                  if (_showSearchResults && _searchResults.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (_isSearching)
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.blue,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Searching...',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ..._searchResults.take(5).map((placemark) => 
                            ListTile(
                              leading: Icon(Icons.location_on, color: Colors.blue),
                              title: Text(
                                placemark.name ?? placemark.street ?? 'Unknown location',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                '${placemark.locality ?? ''}, ${placemark.country ?? ''}'.trim(),
                                style: TextStyle(fontSize: 12),
                              ),
                              onTap: () => _selectSearchResult(placemark),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Loading indicator
            if (_isLoadingLocation)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Getting your location...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print('Location button pressed');
          _getCurrentLocation();
        },
        heroTag: "location",
        tooltip: 'Get my location',
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
      ),
    );
  }
}
