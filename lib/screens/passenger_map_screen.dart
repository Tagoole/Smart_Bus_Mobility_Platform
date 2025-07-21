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
    target: LatLng(0.34540783865964797, 32.54297125499706), // Kampala coordinates
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
  List<Map<String, dynamic>> _availableBuses = [];
  final Set<Marker> _allMarkers = {};
  final Set<Marker> _searchMarkers = {};
  final Set<Polyline> _polylines = {};
  final Mode _mode = Mode.overlay;
  bool _isRefreshingBuses = false;

  LatLng? _busLocation;
  Map<String, dynamic>? _selectedBus;
  StreamSubscription<QuerySnapshot>? _bookingSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _listenToBookings();
    _pickupController.addListener(_updatePickupFromText);
    _destinationController.addListener(_updateDestinationFromText);
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
      print('Error getting location: $e');
      setState(() {
        _isLoadingLocation = false;
      });
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

    if (_pickupLocation != null && _userMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('pickup_location'),
          position: _pickupLocation!,
          icon: _userMarkerIcon!,
          infoWindow: InfoWindow(title: 'Pickup Location'),
        ),
      );
    }

    if (_destinationLocation != null && _userMarkerIcon != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('destination_location'),
          position: _destinationLocation!,
          icon: _userMarkerIcon!,
          infoWindow: InfoWindow(title: 'Destination'),
        ),
      );
    }

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
            onTap: () => _selectBus(bus),
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
      print('Invalid coordinates: origin=$origin, destination=$destination');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid coordinates provided'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final String url =
          'https://maps.googleapis.com/maps/api/directions/json'
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
      print('Error drawing polyline: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching route: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _selectBus(Map<String, dynamic> bus) {
    setState(() {
      _selectedBus = bus;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeatSelectionScreen(
          bus: bus,
          pickupLocation: _pickupLocation!,
          destinationLocation: _destinationLocation!,
        ),
      ),
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
      decoration: InputDecoration(
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
      decoration: InputDecoration(
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
    controller.animateCamera(CameraUpdate.newLatLngZoom(_pickupLocation!, 14.0));

    if (_pickupLocation != null && _destinationLocation != null) {
      await _saveLocations();
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
      _searchMarkers.removeWhere((m) => m.markerId.value == 'destination_location');
      _searchMarkers.add(
        Marker(
          markerId: const MarkerId('destination_location'),
          position: _destinationLocation!,
          icon: _userMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination: ${detail.result.name}'),
        ),
      );
    });

    final controller = _mapController ?? await _controller.future;
    controller
        .animateCamera(CameraUpdate.newLatLngZoom(_destinationLocation!, 14.0));

    if (_pickupLocation != null && _destinationLocation != null) {
      await _saveLocations();
      await _drawRoutePolyline(_pickupLocation!, _destinationLocation!);
      showAllAvailableBusesSheet();
    }
  }

  Future<void> _saveLocations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pickupLocation': {
          'latitude': _pickupLocation!.latitude,
          'longitude': _pickupLocation!.longitude,
          'name': _pickupController.text,
        },
        'destinationLocation': {
          'latitude': _destinationLocation!.latitude,
          'longitude': _destinationLocation!.longitude,
          'name': _destinationController.text,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving locations: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving locations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _updatePickupFromText() {
    if (_pickupController.text.isNotEmpty && _pickupLocation == null) {
      setState(() {
        _pickupLocation = _currentLocation;
        _searchMarkers.removeWhere((m) => m.markerId.value == 'pickup_location');
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

  void _updateDestinationFromText() {
    if (_destinationController.text.isNotEmpty && _destinationLocation == null) {
      setState(() {
        _destinationLocation = _currentLocation;
        _searchMarkers.removeWhere((m) => m.markerId.value == 'destination_location');
        _searchMarkers.add(
          Marker(
            markerId: const MarkerId('destination_location'),
            position: _destinationLocation!,
            icon: _userMarkerIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Destination: ${_destinationController.text}'),
          ),
        );
      });
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
      _searchMarkers.removeWhere((m) => m.markerId.value == 'destination_location');
      _polylines.clear();
    });
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: const Icon(Icons.directions_bus, color: Colors.green),
                          ),
                          title: Text(
                            '${bus['startPoint'] ?? 'Unknown'} → ${bus['destination'] ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Bus: ${bus['numberPlate'] ?? 'Unknown'}'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _selectBus(bus),
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
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Pick Up',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _pickupController,
                            onTap: _handlePickupSelection,
                            decoration: InputDecoration(
                              hintText: 'Type or select location',
                              border: InputBorder.none,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, size: 16),
                                    onPressed: _handlePickupSelection,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.clear, size: 16),
                                    onPressed: _clearPickup,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Where To',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
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
                                    icon: Icon(Icons.edit, size: 16),
                                    onPressed: _handleDestinationSelection,
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.clear, size: 16),
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
        ],
      ),
    );
  }
}

class SeatSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> bus;
  final LatLng pickupLocation;
  final LatLng destinationLocation;

  const SeatSelectionScreen({
    super.key,
    required this.bus,
    required this.pickupLocation,
    required this.destinationLocation,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  List<int> selectedSeats = [];
  List<int> bookedSeats = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookedSeats();
  }

  Future<void> _loadBookedSeats() async {
    try {
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('busId', isEqualTo: widget.bus['busId'])
          .where('status', isEqualTo: 'confirmed')
          .get();

      List<int> tempBookedSeats = [];
      for (var doc in bookingsSnapshot.docs) {
        if (doc.data()['seatNumber'] != null) {
          tempBookedSeats.add(doc.data()['seatNumber']);
        }
      }

      setState(() {
        bookedSeats = tempBookedSeats;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading booked seats: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _toggleSeatSelection(int seatNumber) {
    setState(() {
      if (selectedSeats.contains(seatNumber)) {
        selectedSeats.remove(seatNumber);
      } else {
        selectedSeats.add(seatNumber);
      }
    });
  }

  void _proceedToPayment() {
    if (selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one seat')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          bus: widget.bus,
          pickupLocation: widget.pickupLocation,
          destinationLocation: widget.destinationLocation,
          selectedSeats: selectedSeats,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSeats = widget.bus['totalSeats'] ?? 40; // Default to 40 seats

    return Scaffold(
      appBar: AppBar(
        title: Text('Select Seats - ${widget.bus['numberPlate'] ?? 'Unknown'}'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Route: ${widget.bus['startPoint'] ?? 'Unknown'} → ${widget.bus['destination'] ?? 'Unknown'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: totalSeats,
                      itemBuilder: (context, index) {
                        final seatNumber = index + 1;
                        final isBooked = bookedSeats.contains(seatNumber);
                        final isSelected = selectedSeats.contains(seatNumber);

                        return GestureDetector(
                          onTap: isBooked ? null : () => _toggleSeatSelection(seatNumber),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isBooked
                                  ? Colors.grey
                                  : isSelected
                                      ? Colors.green
                                      : Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$seatNumber',
                                style: TextStyle(
                                  color: isBooked ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: selectedSeats.isEmpty ? null : _proceedToPayment,
                    child: const Text('Proceed to Payment'),
                  ),
                ],
              ),
            ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> bus;
  final LatLng pickupLocation;
  final LatLng destinationLocation;
  final List<int> selectedSeats;

  const PaymentScreen({
    super.key,
    required this.bus,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.selectedSeats,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool isProcessing = false;

  Future<void> _processPayment() async {
    setState(() {
      isProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create booking for each selected seat
      for (var seatNumber in widget.selectedSeats) {
        await FirebaseFirestore.instance.collection('bookings').add({
          'userId': user.uid,
          'busId': widget.bus['busId'],
          'seatNumber': seatNumber,
          'pickupLocation': {
            'latitude': widget.pickupLocation.latitude,
            'longitude': widget.pickupLocation.longitude,
          },
          'destinationLocation': {
            'latitude': widget.destinationLocation.latitude,
            'longitude': widget.destinationLocation.longitude,
          },
          'status': 'confirmed',
          'createdAt': FieldValue.serverTimestamp(),
          'fare': widget.bus['fare'] ?? 0,
        });

        // Update bus available seats
        final availableSeats = widget.bus['availableSeats'] ?? widget.bus['totalSeats'] ?? 40;
        await FirebaseFirestore.instance
            .collection('buses')
            .doc(widget.bus['busId'])
            .update({
          'availableSeats': availableSeats - 1,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful! Booking confirmed.')),
      );

      // Navigate back to dashboard
      Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
    } catch (e) {
      print('Error processing payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fare = widget.bus['fare'] ?? 0;
    final totalFare = fare * widget.selectedSeats.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bus: ${widget.bus['numberPlate'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Route: ${widget.bus['startPoint'] ?? 'Unknown'} → ${widget.bus['destination'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Selected Seats: ${widget.selectedSeats.join(', ')}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Total Fare: UGX $totalFare',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isProcessing ? null : _processPayment,
              child: isProcessing
                  ? const CircularProgressIndicator()
                  : const Text('Confirm Payment'),
            ),
          ],
        ),
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
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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