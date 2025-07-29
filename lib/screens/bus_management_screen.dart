import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_model.dart';
import 'package:smart_bus_mobility_platform1/screens/admin_search_screen.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_polyline_points/flutter_polyline_points.dart'; // Add this import
import 'package:intl/intl.dart';

const kGoogleApiKey =
    'YOUR_API_KEY'; // Replace with your valid Google Maps API key

class BusManagementScreen extends StatefulWidget {
  const BusManagementScreen({super.key});

  @override
  State<BusManagementScreen> createState() => _BusManagementScreenState();
}

class _BusManagementScreenState extends State<BusManagementScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Data holders
  List<BusModel> buses = [];
  List<Map<String, dynamic>> drivers = [];
  bool isLoading = true;
  bool isAddingBus = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _numberPlateController = TextEditingController();
  final _startPointController = TextEditingController();
  final _destinationController = TextEditingController();
  final _fareController = TextEditingController();
  final _departureTimeController = TextEditingController();
  final _dayController = TextEditingController(); // For typing the date

  // Dropdown selections for date and time
  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedHour;
  int? _selectedMinute;
  String _selectedAmPm = 'AM';

  // Dropdown selections
  String? selectedDriverEmail;
  String? selectedVehicleModel;

  // Vehicle models
  static const List<String> vehicleModels = [
    'Mercedes-Benz Sprinter',
    'Mercedes-Benz O500',
    'BMW X5',
    'Toyota Coaster',
    'Toyota Hiace',
    'Ford Transit',
    'Volkswagen Crafter',
    'Iveco Daily',
  ];

  // Constant seat capacity
  static const int seatCapacity = 30;

  // Map-related variables
  GoogleMapController? _mapController;
  LatLng? _startLatLng;
  LatLng? _destinationLatLng;
  Directions? _routeInfo;
  bool _isLoadingRoute = false;
  Set<Polyline> _routePolylines = {};
  Set<Marker> _routeMarkers = {};
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _numberPlateController.dispose();
    _startPointController.dispose();
    _destinationController.dispose();
    _fareController.dispose();
    _departureTimeController.dispose();
    _dayController.dispose(); // Dispose the new controller
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([_loadBuses(), _loadDrivers()]);
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadBuses() async {
    try {
      final snapshot = await _firestore.collection('buses').get();
      setState(() => buses = snapshot.docs
          .map((doc) => BusModel.fromJson(doc.data(), doc.id))
          .toList());
    } catch (e) {
      print('Error loading buses: $e');
      setState(() => buses = []);
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Driver')
          .get();
      setState(() => drivers = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'email': data['email'] ?? '',
              'name': data['name'] ?? data['email'] ?? 'Unknown Driver',
            };
          }).toList());
    } catch (e) {
      print('Error loading drivers: $e');
      setState(() => drivers = []);
    }
  }

  Future<void> _searchLocation({required bool isStart}) async {
    Prediction? prediction = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      mode: Mode.overlay,
      language: 'en',
      strictbounds: false,
      types: [''],
      decoration: InputDecoration(
        hintText:
            isStart ? 'Search start location...' : 'Search destination...',
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
      components: [Component(Component.country, 'ug')],
    );

    if (prediction != null) {
      try {
        GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
        PlacesDetailsResponse detail =
            await places.getDetailsByPlaceId(prediction.placeId!);
        final lat = detail.result.geometry!.location.lat;
        final lng = detail.result.geometry!.location.lng;
        final address =
            detail.result.formattedAddress ?? prediction.description ?? '';

        setState(() {
          if (isStart) {
            _startPointController.text = address;
            _startLatLng = LatLng(lat, lng);
          } else {
            _destinationController.text = address;
            _destinationLatLng = LatLng(lat, lng);
          }
          _updateMapMarkers();
        });

        if (_startLatLng != null && _destinationLatLng != null) {
          setState(() => _showPreview = true);
          await _fetchRoute();
        }
      } catch (e) {
        print('Error fetching place details: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error fetching location: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _fetchRoute() async {
    if (_startLatLng == null || _destinationLatLng == null) return;

    setState(() => _isLoadingRoute = true);
    try {
      final directions = await DirectionsRepository().getDirections(
        origin: _startLatLng!,
        destination: _destinationLatLng!,
      );

      print('Directions response: $directions');
      print('Polyline points count: ${directions?.polylinePoints.length}');

      if (directions != null && directions.polylinePoints.isNotEmpty) {
        // Convert List<PointLatLng> to List<LatLng>
        List<LatLng> routeCoords = directions.polylinePoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        setState(() {
          _routeInfo = directions;
          _routePolylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routeCoords,
              color: const Color(0xFF576238),
              width: 5,
            ),
          };
          _routeMarkers = {
            Marker(
              markerId: const MarkerId('start'),
              position: _startLatLng!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow:
                  InfoWindow(title: 'Start: ${_startPointController.text}'),
            ),
            Marker(
              markerId: const MarkerId('destination'),
              position: _destinationLatLng!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                  title: 'Destination: ${_destinationController.text}'),
            ),
          };
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(_getBounds(routeCoords), 50),
          );
        }
      } else {
        print('No valid route found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid route found between the selected points'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error fetching route: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching route: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoadingRoute = false);
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
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

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points.map((p) => p.latitude).reduce(min);
    double maxLat = points.map((p) => p.latitude).reduce(max);
    double minLng = points.map((p) => p.longitude).reduce(min);
    double maxLng = points.map((p) => p.longitude).reduce(max);

    const padding = 0.01;
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  void _updateMapMarkers() {
    final markers = <Marker>{};
    if (_startLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: _startLatLng!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Start: ${_startPointController.text}'),
        ),
      );
    }
    if (_destinationLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow:
              InfoWindow(title: 'Destination: ${_destinationController.text}'),
        ),
      );
    }
    setState(() => _routeMarkers = markers);
  }

  Future<void> _addBus() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDriverEmail == null ||
        selectedVehicleModel == null ||
        _startLatLng == null ||
        _destinationLatLng == null ||
        _routePolylines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please complete all required fields and ensure a valid route is selected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isAddingBus = true);
    try {
      final busData = {
        'numberPlate': _numberPlateController.text.trim(),
        'vehicleModel': selectedVehicleModel,
        'driverId': selectedDriverEmail,
        'routeId': 'auto-generated',
        'startPoint': _startPointController.text.trim(),
        'startLat': _startLatLng!.latitude,
        'startLng': _startLatLng!.longitude,
        'destination': _destinationController.text.trim(),
        'destinationLat': _destinationLatLng!.latitude,
        'destinationLng': _destinationLatLng!.longitude,
        'routePolyline': _routePolylines.first.points
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'fare': double.parse(_fareController.text.trim()),
        'departureTime': (_selectedYear != null &&
                _selectedMonth != null &&
                _dayController.text.isNotEmpty &&
                _selectedHour != null &&
                _selectedMinute != null)
            ? DateTime(
                _selectedYear!,
                _selectedMonth!,
                int.parse(_dayController.text),
                (_selectedHour! % 12) + (_selectedAmPm == 'PM' ? 12 : 0),
                _selectedMinute!,
              ).toIso8601String()
            : null,
        'seatCapacity': seatCapacity,
        'availableSeats': seatCapacity,
        'status': 'active',
        'isAvailable': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'currentLocation': {
          'latitude': _startLatLng!.latitude,
          'longitude': _startLatLng!.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      };

      await _firestore.collection('buses').add(busData);

      _formKey.currentState!.reset();
      _numberPlateController.clear();
      _startPointController.clear();
      _destinationController.clear();
      _fareController.clear();
      _departureTimeController.clear();
      setState(() {
        selectedDriverEmail = null;
        selectedVehicleModel = null;
        _startLatLng = null;
        _destinationLatLng = null;
        _routeInfo = null;
        _routePolylines.clear();
        _routeMarkers.clear();
        _showPreview = false;
      });

      await _loadBuses();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding bus: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error adding bus: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isAddingBus = false);
    }
  }

  Future<void> _deleteBus(String busId) async {
    try {
      await _firestore.collection('buses').doc(busId).delete();
      await _loadBuses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting bus: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error deleting bus: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleBusAvailability(BusModel bus) async {
    try {
      await _firestore.collection('buses').doc(bus.busId).update({
        'isAvailable': !bus.isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _loadBuses();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Bus ${bus.isAvailable ? 'deactivated' : 'activated'} successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error updating bus: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error updating bus: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF576238)))
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBusDialog,
        backgroundColor: const Color(0xFF576238),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Bus'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_back,
                  color: Color(0xFF576238), size: 24),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF576238), Color(0xFF6B7244)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF576238).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
              ],
            ),
            child:
                const Icon(Icons.directions_bus, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bus Management',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827))),
                SizedBox(height: 4),
                Text('Manage your fleet of buses',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: const Color(0xFFE8F5E8),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              '${buses.length} Buses',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF576238)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (buses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.directions_bus_outlined,
                  size: 64, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            const Text('No buses found',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
            const SizedBox(height: 8),
            const Text('Add your first bus to get started',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: buses.length,
      itemBuilder: (context, index) => _buildBusCard(buses[index]),
    );
  }

  Widget _buildBusCard(BusModel bus) {
    final driver = drivers.firstWhere((d) => d['email'] == bus.driverId,
        orElse: () => {'name': 'Unknown Driver'});
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: bus.isAvailable
                ? const Color(0xFFE8F5E8)
                : const Color(0xFFFEE2E2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bus.isAvailable
                        ? const Color(0xFFE8F5E8)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: bus.isAvailable
                        ? const Color(0xFF576238)
                        : const Color(0xFFDC2626),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bus.numberPlate,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827))),
                      const SizedBox(height: 2),
                      Text(bus.vehicleModel,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: bus.isAvailable
                        ? const Color(0xFFE8F5E8)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    bus.isAvailable ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: bus.isAvailable
                          ? const Color(0xFF576238)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route,
                          size: 14, color: Color(0xFF576238)),
                      const SizedBox(width: 6),
                      const Text('Route',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF576238))),
                      const Spacer(),
                      if (bus.routePolyline != null &&
                          bus.routePolyline!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E8),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('Mapped',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF576238))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${bus.startPoint} → ${bus.destination}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF111827)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _buildInfoItem(
                        'Capacity',
                        '${bus.availableSeats}/${bus.seatCapacity}',
                        Icons.people)),
                Expanded(
                    child: _buildInfoItem(
                        'Fare',
                        'UGX ${bus.fare.toStringAsFixed(0)}',
                        Icons.attach_money)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Driver',
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF6B7280))),
                        Text(driver['name'],
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleBusAvailability(bus),
                    icon: Icon(bus.isAvailable ? Icons.pause : Icons.play_arrow,
                        size: 14),
                    label: Text(bus.isAvailable ? 'Deactivate' : 'Activate',
                        style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: bus.isAvailable
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF576238),
                      side: BorderSide(
                          color: bus.isAvailable
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF576238)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteBus(bus.busId),
                    icon: const Icon(Icons.delete, size: 14),
                    label: const Text('Delete', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            if (bus.departureTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 16, color: Color(0xFF576238)),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, yyyy – hh:mm a')
                          .format(bus.departureTime!),
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF576238)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  void _showAddBusDialog() {
    // Clear previous selections when opening the dialog
    _dayController.clear();
    _departureTimeController.clear();
    _selectedYear = null;
    _selectedMonth = null;
    _selectedHour = null;
    _selectedMinute = null;
    _selectedAmPm = 'AM';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
              maxWidth: MediaQuery.of(context).size.width * 0.95),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF576238),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_business,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text('Add New Bus',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white)),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _numberPlateController,
                          label: 'Number Plate',
                          hint: 'UAB 123A',
                          validator: (value) => value?.isEmpty ?? true
                              ? 'Please enter number plate'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'Driver',
                          value: selectedDriverEmail,
                          items: drivers
                              .map((driver) => DropdownMenuItem<String>(
                                  value: driver['email'],
                                  child: Text(driver['name'],
                                      style: const TextStyle(fontSize: 14))))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedDriverEmail = value),
                          validator: (value) =>
                              value == null ? 'Please select a driver' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'Vehicle Model',
                          value: selectedVehicleModel,
                          items: vehicleModels
                              .map((model) => DropdownMenuItem(
                                  value: model,
                                  child: Text(model,
                                      style: const TextStyle(fontSize: 14))))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => selectedVehicleModel = value),
                          validator: (value) => value == null
                              ? 'Please select a vehicle model'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.map,
                                      color: Color(0xFF576238), size: 20),
                                  SizedBox(width: 8),
                                  Text('Route Selection',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF111827))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _navigateToMapScreen('start'),
                                      icon: const Icon(Icons.location_on,
                                          size: 18),
                                      label: const Text('Select Start'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF90EE90),
                                        foregroundColor:
                                            const Color(0xFF111827),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _navigateToMapScreen('destination'),
                                      icon: const Icon(Icons.location_on,
                                          size: 18),
                                      label: const Text('Select Stop'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFF6B6B),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_startPointController.text.isNotEmpty ||
                                  _destinationController.text.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_startPointController
                                          .text.isNotEmpty) ...[
                                        Row(
                                          children: [
                                            Container(
                                                width: 12,
                                                height: 12,
                                                decoration: const BoxDecoration(
                                                    color: Color(0xFF90EE90),
                                                    shape: BoxShape.circle)),
                                            const SizedBox(width: 8),
                                            const Text('Start:',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF576238))),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 20, top: 4),
                                          child: Text(
                                              _startPointController.text,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF111827))),
                                        ),
                                      ],
                                      if (_destinationController
                                          .text.isNotEmpty) ...[
                                        if (_startPointController
                                            .text.isNotEmpty)
                                          const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                                width: 12,
                                                height: 12,
                                                decoration: const BoxDecoration(
                                                    color: Color(0xFFFF6B6B),
                                                    shape: BoxShape.circle)),
                                            const SizedBox(width: 8),
                                            const Text('Destination:',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFFDC2626))),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 20, top: 4),
                                          child: Text(
                                              _destinationController.text,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFF111827))),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_startPointController.text.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFFFEAA7)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning,
                                    color: Color(0xFF856404), size: 16),
                                SizedBox(width: 8),
                                Text('Please select a start location',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF856404))),
                              ],
                            ),
                          ),
                        if (_destinationController.text.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFFFEAA7)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning,
                                    color: Color(0xFF856404), size: 16),
                                SizedBox(width: 8),
                                Text('Please select a destination',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF856404))),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _fareController,
                          label: 'Fare (UGX)',
                          hint: 'e.g., 15000',
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter fare';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AbsorbPointer(
                          child: _buildTextField(
                            controller: _departureTimeController,
                            label: 'Selected Departure Time',
                            hint: 'Date and time will appear here',
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Date selection row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedMonth,
                                items: List.generate(12, (i) => i + 1)
                                    .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(DateFormat('MMM')
                                            .format(DateTime(2000, m)))))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedMonth = val),
                                decoration:
                                    const InputDecoration(labelText: 'Month'),
                                validator: (val) =>
                                    val == null ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTextField(
                                controller: _dayController,
                                label: 'Date',
                                hint: 'e.g., 25',
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  final day = int.tryParse(value);
                                  if (day == null) return 'Invalid';
                                  if (_selectedMonth != null &&
                                      _selectedYear != null) {
                                    final maxDays = _daysInMonth(
                                        _selectedYear!, _selectedMonth!);
                                    if (day < 1 || day > maxDays) {
                                      return '1-$maxDays';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedYear,
                                items: List.generate(
                                        2, (i) => DateTime.now().year + i)
                                    .map((y) => DropdownMenuItem(
                                        value: y, child: Text(y.toString())))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedYear = val),
                                decoration:
                                    const InputDecoration(labelText: 'Year'),
                                validator: (val) =>
                                    val == null ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Time selection row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedHour,
                                items: List.generate(12, (i) => i + 1)
                                    .map((h) => DropdownMenuItem(
                                        value: h,
                                        child:
                                            Text(h.toString().padLeft(2, '0'))))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedHour = val),
                                decoration:
                                    const InputDecoration(labelText: 'Hour'),
                                validator: (val) =>
                                    val == null ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: _selectedMinute,
                                items: List.generate(12, (i) => i * 5)
                                    .map((m) => DropdownMenuItem(
                                        value: m,
                                        child:
                                            Text(m.toString().padLeft(2, '0'))))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedMinute = val),
                                decoration:
                                    const InputDecoration(labelText: 'Minute'),
                                validator: (val) =>
                                    val == null ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedAmPm,
                                items: ['AM', 'PM']
                                    .map((p) => DropdownMenuItem(
                                        value: p, child: Text(p)))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _selectedAmPm = val ?? 'AM'),
                                decoration:
                                    const InputDecoration(labelText: 'AM/PM'),
                              ),
                            ),
                          ],
                        ),
                        // Builder to update the display text field
                        Builder(builder: (context) {
                          if (_selectedYear != null &&
                              _selectedMonth != null &&
                              _dayController.text.isNotEmpty &&
                              int.tryParse(_dayController.text) != null &&
                              _selectedHour != null &&
                              _selectedMinute != null) {
                            final day = int.parse(_dayController.text);
                            final hour = (_selectedHour! % 12) +
                                (_selectedAmPm == 'PM' ? 12 : 0);
                            final dt = DateTime(
                              _selectedYear!,
                              _selectedMonth!,
                              day,
                              hour,
                              _selectedMinute!,
                            );
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _departureTimeController.text =
                                    DateFormat('MMM d, yyyy – hh:mm a')
                                        .format(dt);
                              }
                            });
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF576238)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isAddingBus ? null : _addBus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF576238),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: isAddingBus
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white)))
                            : const Text('Add Bus'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF576238))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF576238))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _navigateToMapScreen(String mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminSearchScreen(
          mode: mode,
          onLocationSelected: (LatLng latLng, String address) async {
            setState(() {
              if (mode == 'start') {
                _startLatLng = latLng;
                _startPointController.text = address;
              } else {
                _destinationLatLng = latLng;
                _destinationController.text = address;
              }
            });
            if (_startLatLng != null && _destinationLatLng != null) {
              setState(() => _showPreview = true);
              await _fetchRoute();
            }
          },
        ),
      ),
    );
  }

  int _daysInMonth(int year, int month) {
    if (month == 12) return 31;
    return DateTime(year, month + 1, 0).day;
  }
}











