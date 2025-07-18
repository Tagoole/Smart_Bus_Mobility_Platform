import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:smart_bus_mobility_platform1/screens/bus_route_preview_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

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
  final Set<Marker> _searchMarkers = {};
  final Mode _mode = Mode.overlay;
  bool _isRefreshingBuses = false;
  Set<Polyline> _routePolylines = {};

  // Example: Replace with actual logic to get these
  LatLng? _busLocation; // Set this to the selected bus's current location
  LatLng? _pickupLocation; // Set this to the selected pickup location

  // Remove FocusNode and listener
  StreamSubscription<QuerySnapshot>? _bookingSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _listenToBookings();
    // No searchController listener needed
  }

  void _listenToBookings() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _bookingSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'confirmed')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final booking = snapshot.docs.first.data();
        if (booking['pickupLocation'] != null && booking['busId'] != null) {
          final pickup = booking['pickupLocation'];
          final busId = booking['busId'];
          // Get bus's current location from Firestore
          final busDoc = await FirebaseFirestore.instance
              .collection('buses')
              .doc(busId)
              .get();
          if (busDoc.exists && busDoc.data()?['currentLocation'] != null) {
            final busLoc = busDoc.data()!['currentLocation'];
            setState(() {
              _pickupLocation = LatLng(pickup['latitude'], pickup['longitude']);
              _busLocation = LatLng(busLoc['latitude'], busLoc['longitude']);
            });
            _drawRoutePolyline();
          }
        }
      }
    });
  }

  // Remove _onSearchChanged and FocusNode logic

  Future<void> _initializeMap() async {
    await _loadMarkerIcons();
    await _getCurrentLocation();
    await _loadAvailableBuses();
  }

  Future<void> _loadMarkerIcons() async {
    try {
      _busMarkerIcon = await MarkerIcons.busIcon;
      // Use the passenger icon for the user marker
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
          .where('status', isEqualTo: 'active')
          .get();

      final List<Map<String, dynamic>> buses = [];
      for (var doc in busesSnapshot.docs) {
        final busData = doc.data();
        buses.add({
          'busId': doc.id,
          ...busData,
        });
      }

      // Debug print: print all fetched buses
      print('--- Fetched Buses (${buses.length}) ---');
      for (var bus in buses) {
        print(bus);
      }
      print('-------------------------------');

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
            onTap: () => _showBusDetailsScreen(context, bus),
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
      icon: _userMarkerIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: detail.result.name),
    ));
    setState(() {});
    final controller = _mapController ?? await _controller.future;
    controller
        .animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.0));
    showAllAvailableBusesSheet();
  }

  void showAllAvailableBusesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_bus, size: 32, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  const Text('All available buses:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              if (_availableBuses.isEmpty) const Text('No buses available.'),
              if (_availableBuses.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _availableBuses.length,
                    itemBuilder: (context, index) {
                      final bus = _availableBuses[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: const Icon(Icons.directions_bus,
                                color: Colors.green),
                          ),
                          title: Text(
                            '${bus['startPoint'] ?? 'Unknown'} → ${bus['destination'] ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle:
                              Text('Bus: ${bus['numberPlate'] ?? 'Unknown'}'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _showBusDetailsScreen(context, bus),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAvailableBusesSheet(String placeName) {
    final filteredBuses = _availableBuses.where((bus) {
      final dest = (bus['destination'] ?? '').toString().toLowerCase();
      final start = (bus['startPoint'] ?? '').toString().toLowerCase();
      final query = placeName.toLowerCase();
      return dest.contains(query) || start.contains(query);
    }).toList();

    if (filteredBuses.isEmpty) {
      showAllAvailableBusesSheet();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) => ListView.builder(
            controller: scrollController,
            itemCount: filteredBuses.length,
            itemBuilder: (context, index) {
              final bus = filteredBuses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child:
                        const Icon(Icons.directions_bus, color: Colors.green),
                  ),
                  title: Text(
                    '${bus['startPoint']} → ${bus['destination']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Bus: ${bus['numberPlate']}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showBusDetailsScreen(context, bus),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _refreshAvailableBuses() async {
    setState(() {
      _isRefreshingBuses = true;
    });
    await _loadAvailableBuses();
    setState(() {
      _isRefreshingBuses = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bus list refreshed!')),
    );
  }

  Future<void> _drawRoutePolyline() async {
    if (_busLocation == null || _pickupLocation == null) return;
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_busLocation!.latitude},${_busLocation!.longitude}&destination=${_pickupLocation!.latitude},${_pickupLocation!.longitude}&mode=driving&key=$kGoogleApiKey';
    final response = await http.get(Uri.parse(url));
    final data = json.decode(response.body);
    if (data['routes'] != null && data['routes'].isNotEmpty) {
      final points = _decodePolyline(
        data['routes'][0]['overview_polyline']['points'],
      );
      setState(() {
        _routePolylines = {
          Polyline(
            polylineId: PolylineId('route'),
            points: points,
            color: Colors.blue,
            width: 5,
          ),
        };
      });
    }
  }

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

  @override
  void dispose() {
    _searchController.dispose();
    _bookingSubscription?.cancel();
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
            polylines: _routePolylines,
          ),
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),
          // Search bar-style button overlay
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () async {
                Prediction? p = await PlacesAutocomplete.show(
                  context: context,
                  apiKey: kGoogleApiKey,
                  mode: _mode,
                  language: 'en',
                  strictbounds: false,
                  types: [""],
                  decoration: InputDecoration(
                    hintText: 'Search for places...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  components: [Component(Component.country, "ug")],
                );
                if (p != null) {
                  await _displayPrediction(p);
                }
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Search for places...',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ],
                ),
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
          // Refresh buses button
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton(
              heroTag: 'refresh',
              onPressed: _isRefreshingBuses ? null : _refreshAvailableBuses,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              child: _isRefreshingBuses
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
          // Sample button to trigger polyline drawing (for demo)
          Positioned(
            bottom: 90,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'draw_route',
              onPressed: _drawRoutePolyline,
              backgroundColor: Colors.orange,
              child: const Icon(Icons.alt_route),
              tooltip: 'Draw route from bus to pickup',
            ),
          ),
        ],
      ),
    );
  }
}

void _showBusDetailsScreen(BuildContext context, Map<String, dynamic> bus) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.75,
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_bus, color: Colors.green, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${bus['startPoint'] ?? 'Unknown'} → ${bus['destination'] ?? 'Unknown'}',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text('Bus Plate: ${bus['numberPlate'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 16)),
              Text('Driver: ${bus['driverId'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 16)),
              Text('Vehicle Model: ${bus['vehicleModel'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 16)),
              Text('Available Seats: ${bus['availableSeats'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 16)),
              Text('Fare: UGX ${bus['fare'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 16)),
              Text('Route ID: ${bus['routeId'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 16)),
              Text('Status: ${bus['status'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              if (bus['routePolyline'] != null &&
                  bus['routePolyline'] is List &&
                  (bus['routePolyline'] as List).isNotEmpty)
                Container(
                  height: 200,
                  margin: EdgeInsets.only(top: 8),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        (bus['routePolyline'][0]['lat'] ?? 0.0) as double,
                        (bus['routePolyline'][0]['lng'] ?? 0.0) as double,
                      ),
                      zoom: 13,
                    ),
                    polylines: {
                      Polyline(
                        polylineId: PolylineId('route'),
                        color: Colors.green,
                        width: 5,
                        points: (bus['routePolyline'] as List)
                            .map<LatLng>((p) => LatLng(p['lat'], p['lng']))
                            .toList(),
                      ),
                    },
                    markers: {
                      Marker(
                        markerId: MarkerId('start'),
                        position: LatLng(
                          (bus['routePolyline'][0]['lat'] ?? 0.0) as double,
                          (bus['routePolyline'][0]['lng'] ?? 0.0) as double,
                        ),
                        infoWindow: InfoWindow(title: 'Start'),
                      ),
                      Marker(
                        markerId: MarkerId('end'),
                        position: LatLng(
                          (bus['routePolyline'].last['lat'] ?? 0.0) as double,
                          (bus['routePolyline'].last['lng'] ?? 0.0) as double,
                        ),
                        infoWindow: InfoWindow(title: 'Destination'),
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    liteModeEnabled: true,
                  ),
                ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Close'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BusRoutePreviewScreen(
                            bus: bus,
                          ),
                        ),
                      );
                    },
                    child: Text('Preview Route'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

