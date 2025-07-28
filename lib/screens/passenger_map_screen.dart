import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_maps_webservice/directions.dart' as directions;
import 'package:smart_bus_mobility_platform1/screens/bus_route_preview_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:smart_bus_mobility_platform1/screens/nav_bar_screen.dart';

const kGoogleApiKey = 'AIzaSyC2n6urW_4DUphPLUDaNGAW_VN53j0RP4s';

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;

  static const CameraPosition _initialPosition = CameraPosition(
    target:
        LatLng(0.34540783865964797, 32.54297125499706), // Kampala coordinates
    zoom: 14,
  );

  // Location tracking
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  BitmapDescriptor? _busMarkerIcon;
  BitmapDescriptor? _userMarkerIcon;
  bool _isLoadingLocation = false;

  // Text controllers for manual input
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // Bus data
  List<BusModel> _availableBuses = [];
  final Set<Marker> _allMarkers = {};
  final Set<Marker> _searchMarkers = {};
  final Set<Polyline> _polylines = {};
  final Mode _mode = Mode.overlay;
  bool _isRefreshingBuses = false;

  LatLng? _busLocation;

  StreamSubscription<QuerySnapshot>? _bookingSubscription;

  @override
  void initState() {
    super.initState();
    print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥DEBUG: initState called');
    _initializeMap();
    _listenToBookings();
    _pickupController.addListener(_updatePickupFromText);
    _destinationController
        .addListener(_onDestinationChanged); // <-- Add this line
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
            if (_pickupLocation != null && _busLocation != null) {
              _drawRoutePolyline(_pickupLocation!, _busLocation!);
            }
          }
        }
      }
    });
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

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
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _currentLocation = const LatLng(0.34540783865964797, 32.54297125499706);
    });
  }

  Future<void> _loadAvailableBuses() async {
    print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥DEBUG: _loadAvailableBuses called');
    try {
      final busesSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('isAvailable', isEqualTo: true)
          .get();

      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥DEBUG: Fetched \u001b[32m${busesSnapshot.docs.length}\u001b[0m buses'); // Debug print
      final List<BusModel> buses = [];
      for (var doc in busesSnapshot.docs) {
        print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥DEBUG: Bus data: \u001b[36m${doc.data()}\u001b[0m'); // Debug print
        buses.add(BusModel.fromJson(doc.data(), doc.id));
      }

      setState(() {
        _availableBuses = buses;
        print('**********************************************************************************************************');
        print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥DEBUG: _availableBuses length after setState:  [35m${_availableBuses.length} [0m');
        print('**********************************************************************************************************');
      });

      _updateMarkers();
    } catch (e) {
      print('**********************************************************************************************************');
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥 ERROR in _loadAvailableBuses: $e');
      print('**********************************************************************************************************');
    }
  }

  void _updateMarkers() {
    _allMarkers.clear();

    if (_currentLocation != null && _userMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          icon: _userMarkerIcon!,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    }

    if (_pickupLocation != null && _userMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: _pickupLocation!,
          icon: _userMarkerIcon!,
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ),
      );
    }

    if (_destinationLocation != null && _userMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: const MarkerId('destination_location'),
          position: _destinationLocation!,
          icon: _userMarkerIcon!,
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }

    for (int i = 0; i < _availableBuses.length; i++) {
      final bus = _availableBuses[i];
      final latLng = bus.getCurrentLocationLatLng();
      if (latLng != null && _busMarkerIcon != null) {
        _allMarkers.add(
          Marker(
            markerId: MarkerId('bus_${bus.busId}'),
            position: latLng,
            icon: _busMarkerIcon!,
            infoWindow: InfoWindow(
              title: 'Bus ${bus.numberPlate}',
              snippet: '${bus.startPoint} → ${bus.destination}',
            ),
            onTap: () => _showBusDetailsScreen(context, bus),
          ),
        );
      }
    }

    setState(() {});
  }

  Future<void> _drawRoutePolyline(LatLng origin, LatLng destination) async {
    if (origin.latitude == 0.0 ||
        origin.longitude == 0.0 ||
        destination.latitude == 0.0 ||
        destination.longitude == 0.0) {
      print('**********************************************************************************************************');
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥Invalid coordinates: origin=$origin, destination=$destination');
      print('**********************************************************************************************************');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid coordinates provided'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final String url = 'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&mode=driving'
          '&key=$kGoogleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final points = data['routes'][0]['overview_polyline']['points'];
          final polylinePoints = PolylinePoints()
              .decodePolyline(points)
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          if (polylinePoints.isNotEmpty) {
            setState(() {
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: polylinePoints,
                  color: Colors.blue,
                  width: 5,
                ),
              );
            });

            final controller = _mapController ?? await _controller.future;
            controller.animateCamera(
              CameraUpdate.newLatLngBounds(
                LatLngBounds(
                  southwest: LatLng(
                    origin.latitude < destination.latitude
                        ? origin.latitude
                        : destination.latitude,
                    origin.longitude < destination.longitude
                        ? origin.longitude
                        : destination.longitude,
                  ),
                  northeast: LatLng(
                    origin.latitude > destination.latitude
                        ? origin.latitude
                        : destination.latitude,
                    origin.longitude > destination.longitude
                        ? origin.longitude
                        : destination.longitude,
                  ),
                ),
                100.0,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('**********************************************************************************************************');
      print('🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥🔥Error drawing polyline: $e');
      print('**********************************************************************************************************');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching route: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBusDetails(Map<String, dynamic> bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bus Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plate: ${bus['numberPlate'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text(
                'Route: ${bus['startPoint'] ?? 'Unknown'} → ${bus['destination'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Driver: ${bus['driverName'] ?? 'Unknown'}'),
            const SizedBox(height: 8),
            Text('Available Seats: ${bus['availableSeats'] ?? 'Unknown'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bookBus(bus);
            },
            child: const Text('Book This Bus'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showBusRoute(bus);
            },
            child: const Text('View Route'),
          ),
        ],
      ),
    );
  }

  void _showBusRoute(Map<String, dynamic> bus) async {
    if (bus['currentLocation'] != null && _currentLocation != null) {
      final busLoc = bus['currentLocation'];
      final busLatLng = LatLng(busLoc['latitude'], busLoc['longitude']);
      if (busLatLng.latitude == 0.0 || busLatLng.longitude == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid bus location'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      await _drawRoutePolyline(_currentLocation!, busLatLng);
      final controller = _mapController ?? await _controller.future;
      controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              _currentLocation!.latitude < busLatLng.latitude
                  ? _currentLocation!.latitude
                  : busLatLng.latitude,
              _currentLocation!.longitude < busLatLng.longitude
                  ? _currentLocation!.longitude
                  : busLatLng.longitude,
            ),
            northeast: LatLng(
              _currentLocation!.latitude > busLatLng.latitude
                  ? _currentLocation!.latitude
                  : busLatLng.latitude,
              _currentLocation!.longitude > busLatLng.longitude
                  ? _currentLocation!.longitude
                  : busLatLng.longitude,
            ),
          ),
          100.0,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Current location or bus location unavailable'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _bookBus(Map<String, dynamic> bus) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking functionality coming soon!')),
    );
  }

  Future<void> _handlePickupSelection() async {
    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      mode: _mode,
      language: 'en',
      strictbounds: false,
      types: [""],
      decoration: const InputDecoration(
        hintText: 'Type or select pickup location',
        border: InputBorder.none,
      ),
      components: [Component(Component.country, "ug")],
    );
    if (p != null) {
      await _setPickupLocation(p);
    }
  }

  Future<void> _handleDestinationSelection() async {
    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      mode: _mode,
      language: 'en',
      strictbounds: false,
      types: [""],
      decoration: const InputDecoration(
        hintText: 'Type or select destination',
        border: InputBorder.none,
      ),
      components: [Component(Component.country, "ug")],
    );
    if (p != null) {
      await _setDestinationLocation(p);
    }
  }

  Future<void> _setPickupLocation(Prediction p) async {
    GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
    PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);
    final lat = detail.result.geometry!.location.lat;
    final lng = detail.result.geometry!.location.lng;
    setState(() {
      _pickupLocation = LatLng(lat, lng);
      _pickupController.text = detail.result.name;
      _searchMarkers.removeWhere((m) => m.markerId.value == 'pickup_location');
      _searchMarkers.add(
        Marker(
          markerId: const MarkerId('pickup_location'),
          position: _pickupLocation!,
          icon: _userMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Pickup: ${detail.result.name}'),
        ),
      );
    });

    final controller = _mapController ?? await _controller.future;
    controller
        .animateCamera(CameraUpdate.newLatLngZoom(_pickupLocation!, 14.0));

    if (_pickupLocation != null && _destinationLocation != null) {
      await _drawRoutePolyline(_pickupLocation!, _destinationLocation!);
      showAllAvailableBusesSheet();
    }
  }

  Future<void> _setDestinationLocation(Prediction p) async {
    GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
    PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);
    final lat = detail.result.geometry!.location.lat;
    final lng = detail.result.geometry!.location.lng;
    setState(() {
      _destinationLocation = LatLng(lat, lng);
      _destinationController.text = detail.result.name;
      _searchMarkers
          .removeWhere((m) => m.markerId.value == 'destination_location');
      _searchMarkers.add(
        Marker(
          markerId: const MarkerId('destination_location'),
          position: _destinationLocation!,
          icon: _userMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination: ${detail.result.name}'),
        ),
      );
      _polylines.clear(); // Remove any route
    });

    final controller = _mapController ?? await _controller.future;
    controller
        .animateCamera(CameraUpdate.newLatLngZoom(_destinationLocation!, 14.0));

    await _loadAvailableBuses();
    showAllAvailableBusesSheet();
  }

  void _updatePickupFromText() {
    if (_pickupController.text.isNotEmpty && _pickupLocation == null) {
      // Simulate geocode for simplicity (in practice, use a geocoder API)
      // This is a placeholder; actual geocode logic would be needed
      setState(() {
        _pickupLocation =
            _currentLocation; // Default to current location for now
        _searchMarkers
            .removeWhere((m) => m.markerId.value == 'pickup_location');
        _searchMarkers.add(
          Marker(
            markerId: const MarkerId('pickup_location'),
            position: _pickupLocation!,
            icon: _userMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Pickup: ${_pickupController.text}'),
          ),
        );
      });
    }
  }

  void _onDestinationChanged() async {
    if (_destinationController.text.isNotEmpty) {
      await _loadAvailableBuses();
      showAllAvailableBusesSheet();

      // Optionally, update the marker if you have geocoding logic
      // Example (pseudo):
      // LatLng? dest = await geocode(_destinationController.text);
      // if (dest != null) {
      //   setState(() {
      //     _destinationLocation = dest;
      //     _searchMarkers.removeWhere((m) => m.markerId.value == 'destination_location');
      //     _searchMarkers.add(
      //       Marker(
      //         markerId: const MarkerId('destination_location'),
      //         position: dest,
      //         icon: _userMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      //         infoWindow: InfoWindow(title: 'Destination: ${_destinationController.text}'),
      //       ),
      //     );
      //     _polylines.clear(); // Remove any route
      //   });
      // }
    }
  }

  void _clearPickup() {
    setState(() {
      _pickupLocation = null;
      _pickupController.clear();
      _searchMarkers.removeWhere((m) => m.markerId.value == 'pickup_location');
      _polylines.clear();
    });
  }

  void _clearDestination() {
    setState(() {
      _destinationLocation = null;
      _destinationController.clear();
      _searchMarkers
          .removeWhere((m) => m.markerId.value == 'destination_location');
      _polylines.clear();
    });
  }

  Future<void> showAllAvailableBusesSheet() async {
    await showModalBottomSheet(
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
                            '${bus.startPoint} → ${bus.destination}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle:
                              Text('Bus: ${bus.numberPlate}'),
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

  Future<void> _refreshAvailableBuses() async {
    setState(() {
      _isRefreshingBuses = true;
    });
    await _loadAvailableBuses();
    setState(() {
      _isRefreshingBuses = false;
      _polylines.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bus list refreshed!')),
    );
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _bookingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => NavBarScreen(userRole: 'user', initialTab: 0),
          ),
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                _mapController = controller;
              },
              initialCameraPosition: _initialPosition,
              markers: _allMarkers.union(_searchMarkers),
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
            if (_isLoadingLocation)
              const Center(child: CircularProgressIndicator()),
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(9.0),
                          child: Text(
                            'Where To:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 7, 7, 7)),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _destinationController,
                            onTap: _handleDestinationSelection,
                            decoration: InputDecoration(
                              hintText: 'Type or select location',
                              border: InputBorder.none,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16),
                                    onPressed: _handleDestinationSelection,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: _clearDestination,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'location',
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                child: _isLoadingLocation
                    ? const SizedBox(
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
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton(
                heroTag: 'refresh',
                onPressed: _isRefreshingBuses ? null : _refreshAvailableBuses,
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                child: _isRefreshingBuses
                    ? const SizedBox(
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
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && args['clearBooking'] == true) {
      _clearAllBookingState();
    }
  }

  void _clearAllBookingState() {
    setState(() {
      // Reset all variables related to previous bookings, overlays, markers, etc.
      // Replace these with your actual variable names!
      _pickupLocation = null;
      _destinationLocation = null;
      _searchMarkers.clear();
      _polylines.clear();
      // ...reset any other relevant state variables you use for bookings or overlays
    });
  }
}

void _showBusDetailsScreen(BuildContext context, BusModel bus) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_bus, color: Colors.green, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${bus.startPoint} → ${bus.destination}',
                      style:
                          const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Bus Plate: ${bus.numberPlate}',
                  style: const TextStyle(fontSize: 16)),
              Text('Driver: ${bus.driverId}',
                  style: const TextStyle(fontSize: 16)),
              Text('Vehicle Model: ${bus.vehicleModel}',
                  style: const TextStyle(fontSize: 16)),
              Text('Available Seats: ${bus.availableSeats}',
                  style: const TextStyle(fontSize: 16)),
              Text('Fare: UGX ${bus.fare}',
                  style: const TextStyle(fontSize: 16)),
              Text('Route ID: ${bus.routeId}',
                  style: const TextStyle(fontSize: 16)),
              Text('Available: ${bus.isAvailable ? 'Yes' : 'No'}',
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Close'),
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
                    child: const Text('Contiue'),
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


