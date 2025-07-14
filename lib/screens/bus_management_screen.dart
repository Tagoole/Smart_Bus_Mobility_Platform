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
import 'dart:math';

class BusManagementScreen extends StatefulWidget {
  const BusManagementScreen({super.key});

  @override
  State<BusManagementScreen> createState() => _BusManagementScreenState();
}

const kGoogleApiKey = 'AIzaSyC2n6urW_4DUphPLUDaNGAW_VN53j0RP4s';

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

  // Form controllers for adding new bus
  final _formKey = GlobalKey<FormState>();
  final _numberPlateController = TextEditingController();
  final _startPointController = TextEditingController();
  final _destinationController = TextEditingController();
  final _fareController = TextEditingController();
  final _departureTimeController = TextEditingController();

  // Dropdown values
  String? selectedDriverEmail;
  String? selectedVehicleModel;

  // Predefined vehicle models
  final List<String> vehicleModels = [
    'Mercedes-Benz Sprinter',
    'Mercedes-Benz O500',
    'BMW X5',
    'Toyota Coaster',
    'Toyota Hiace',
    'Ford Transit',
    'Volkswagen Crafter',
    'Iveco Daily',
  ];

  // Constant seat capacity for all buses
  static const int constantSeatCapacity = 30;

  // Map-related variables
  LatLng? _startLatLng;
  LatLng? _destinationLatLng;
  Directions? _routeInfo;
  bool _isLoadingRoute = false;
  GoogleMapController? _mapController;
  Set<Polygon> _serviceAreaPolygons = {};
  Set<Polyline> _routePolylines = {};
  Set<Marker> _routeMarkers = {};

  // Preview variables
  bool _showPreview = false;
  double _serviceAreaRadius = 0.01; // Default 1km radius

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
    _loadData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _numberPlateController.dispose();
    _startPointController.dispose();
    _destinationController.dispose();
    _fareController.dispose();
    _departureTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load buses and drivers in parallel
      await Future.wait([_loadBuses(), _loadDrivers()]);
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _loadBuses() async {
    try {
      final snapshot = await _firestore.collection('buses').get();
      setState(() {
        buses = snapshot.docs.map((doc) {
          final data = doc.data();
          return BusModel.fromJson(data, doc.id);
        }).toList();
      });
    } catch (e) {
      print('Error loading buses: $e');
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Driver')
          .get();

      setState(() {
        drivers = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'uid': doc.id,
            'email': data['email'] ?? '',
            'name': data['name'] ?? data['email'] ?? 'Unknown Driver',
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading drivers: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _searchLocation({required bool isStart}) async {
    final instructions =
        isStart ? 'Search Start Location' : 'Search Destination';

    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      onError: (PlacesAutocompleteResponse response) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(response.errorMessage ?? 'Error searching location'),
          backgroundColor: Colors.red,
        ));
      },
      mode: Mode.overlay,
      language: 'en',
      strictbounds: false,
      types: [""],
      decoration: InputDecoration(
          hintText:
              isStart ? 'Search start location...' : 'Search destination...',
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.white))),
      components: [Component(Component.country, "ug")],
    );

    if (p != null) {
      // Get place details
      GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
      PlacesDetailsResponse detail =
          await places.getDetailsByPlaceId(p.placeId!);

      final address = detail.result.formattedAddress ?? p.description ?? '';
      final lat = detail.result.geometry!.location.lat;
      final lng = detail.result.geometry!.location.lng;

      setState(() {
        if (isStart) {
          _startPointController.text = address;
          _startLatLng = LatLng(lat, lng);
        } else {
          _destinationController.text = address;
          _destinationLatLng = LatLng(lat, lng);
        }
      });

      // Update markers
      _updateMapMarkers();

      // Only fetch route and show preview if both locations are set
      if (_startLatLng != null && _destinationLatLng != null) {
        setState(() {
          _showPreview = true;
        });
        await _fetchRouteAndServiceArea();
      }
    }
  }

  Future<void> _fetchRouteAndServiceArea() async {
    if (_startLatLng == null || _destinationLatLng == null) return;

    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // Fetch route directions
      final directions = await DirectionsRepository().getDirections(
        origin: _startLatLng!,
        destination: _destinationLatLng!,
      );

      // Create route polyline (simplified - direct line between start and end)
      final polylinePoints = [_startLatLng!, _destinationLatLng!];

      // Create service area polygon around the route
      final serviceAreaPoints = _createServiceAreaPolygon(polylinePoints);

      setState(() {
        _routeInfo = directions;
        _routePolylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: polylinePoints,
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
            infoWindow: InfoWindow(
              title: 'Start: ${_startPointController.text}',
            ),
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: _destinationLatLng!,
            icon:
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'Destination: ${_destinationController.text}',
            ),
          ),
        };
        _serviceAreaPolygons = {
          Polygon(
            polygonId: const PolygonId('service_area'),
            points: serviceAreaPoints,
            fillColor: const Color(0xFF576238).withOpacity(0.1),
            strokeColor: const Color(0xFF576238),
            strokeWidth: 2,
          ),
        };
        _isLoadingRoute = false;
      });

      // Animate camera to show the entire route
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(_getBounds(polylinePoints), 50),
        );
      }
    } catch (e) {
      print('Error fetching route: $e');
      setState(() {
        _isLoadingRoute = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching route: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<LatLng> _createServiceAreaPolygon(List<LatLng> routePoints) {
    if (routePoints.length < 2) return [];

    List<LatLng> serviceAreaPoints = [];

    // Create points around the route
    for (int i = 0; i < routePoints.length; i += 5) {
      // Sample every 5th point
      final point = routePoints[i];

      // Create a circle around this point
      for (int angle = 0; angle < 360; angle += 30) {
        // Every 30 degrees
        final radians = angle * (3.14159 / 180);
        final lat = point.latitude + (_serviceAreaRadius * cos(radians));
        final lng = point.longitude + (_serviceAreaRadius * sin(radians));
        serviceAreaPoints.add(LatLng(lat, lng));
      }
    }

    // Add points around start and destination
    final startCircle = _createCircle(_startLatLng!, _serviceAreaRadius * 1.5);
    final destCircle =
        _createCircle(_destinationLatLng!, _serviceAreaRadius * 1.5);
    serviceAreaPoints.addAll(startCircle);
    serviceAreaPoints.addAll(destCircle);

    return serviceAreaPoints;
  }

  List<LatLng> _createCircle(LatLng center, double radius) {
    List<LatLng> points = [];
    for (int angle = 0; angle <= 360; angle += 10) {
      final radians = angle * (3.14159 / 180);
      final lat = center.latitude + (radius * cos(radians));
      final lng = center.longitude + (radius * sin(radians));
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;

    for (final point in points) {
      minLat = minLat == null ? point.latitude : min(minLat, point.latitude);
      maxLat = maxLat == null ? point.latitude : max(maxLat, point.latitude);
      minLng = minLng == null ? point.longitude : min(minLng, point.longitude);
      maxLng = maxLng == null ? point.longitude : max(maxLng, point.longitude);
    }

    // Add some padding
    const padding = 0.01;
    return LatLngBounds(
      southwest: LatLng(minLat! - padding, minLng! - padding),
      northeast: LatLng(maxLat! + padding, maxLng! + padding),
    );
  }

  void _updateServiceAreaRadius(double newRadius) {
    setState(() {
      _serviceAreaRadius = newRadius;
    });
    if (_startLatLng != null && _destinationLatLng != null) {
      _fetchRouteAndServiceArea();
    }
  }

  void _updateMapMarkers() {
    Set<Marker> newMarkers = {};

    if (_startLatLng != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('start'),
        position: _startLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Start: ${_startPointController.text}',
        ),
      ));
    }

    if (_destinationLatLng != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destinationLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destination: ${_destinationController.text}',
        ),
      ));
    }

    setState(() {
      _routeMarkers = newMarkers;
    });
  }

  Future<void> _addBus() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedDriverEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a driver'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (selectedVehicleModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vehicle model'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_startLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a destination'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isAddingBus = true;
    });

    try {
      // Find the driver UID from the selected email
      final selectedDriver = drivers.firstWhere(
        (driver) => driver['email'] == selectedDriverEmail,
      );

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
        'routePolyline': [_startLatLng!, _destinationLatLng!]
            .map((p) => {
                  'lat': p.latitude,
                  'lng': p.longitude,
                })
            .toList(),
        'serviceAreaPolygon': _serviceAreaPolygons.isNotEmpty
            ? _serviceAreaPolygons.first.points
                .map((p) => {
                      'lat': p.latitude,
                      'lng': p.longitude,
                    })
                .toList()
            : [],
        'fare': double.parse(_fareController.text.trim()),
        'departureTime': _departureTimeController.text.trim(),
        'seatCapacity': constantSeatCapacity,
        'availableSeats': constantSeatCapacity,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('buses').add(busData);

      // Clear form and map
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
        _serviceAreaPolygons.clear();
        _showPreview = false;
      });

      // Reload buses
      await _loadBuses();

      // Close dialog
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus added successfully with route visualization!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error adding bus: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding bus: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isAddingBus = false;
      });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting bus: $e'),
          backgroundColor: Colors.red,
        ),
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
            'Bus ${bus.isAvailable ? 'deactivated' : 'activated'} successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating bus: $e'),
          backgroundColor: Colors.red,
        ),
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
                        child: CircularProgressIndicator(
                          color: Color(0xFF576238),
                        ),
                      )
                    : _buildContent(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBusDialog(),
        backgroundColor: const Color(0xFF576238),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Bus'),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                child: const Icon(
                  Icons.arrow_back,
                  color: Color(0xFF576238),
                  size: 24,
                ),
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
                    color: const Color(0xFF576238).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bus Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage your fleet of buses',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${buses.length} Buses',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF576238),
                ),
              ),
            ),
          ],
        ),
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.directions_bus_outlined,
                size: 64,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No buses found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first bus to get started',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: buses.length,
      itemBuilder: (context, index) {
        final bus = buses[index];
        return _buildBusCard(bus);
      },
    );
  }

  Widget _buildBusCard(BusModel bus) {
    // Find driver name from email
    final driver = drivers.firstWhere(
      (d) => d['email'] == bus.driverId,
      orElse: () => {'name': 'Unknown Driver'},
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bus.isAvailable
              ? const Color(0xFFE8F5E8)
              : const Color(0xFFFEE2E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                      Text(
                        bus.numberPlate,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        bus.vehicleModel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
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
            // Route info
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
                      Icon(
                        Icons.route,
                        size: 14,
                        color: const Color(0xFF576238),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Route',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF576238),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bus.startPoint} → ${bus.destination}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Stats row
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Capacity',
                    '${bus.availableSeats}/${bus.seatCapacity}',
                    Icons.people,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Fare',
                    'UGX ${bus.fare.toStringAsFixed(0)}',
                    Icons.attach_money,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Driver info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 14, color: const Color(0xFF6B7280)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Driver',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          driver['name'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleBusAvailability(bus),
                    icon: Icon(
                      bus.isAvailable ? Icons.pause : Icons.play_arrow,
                      size: 14,
                    ),
                    label: Text(
                      bus.isAvailable ? 'Deactivate' : 'Activate',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: bus.isAvailable
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF576238),
                      side: BorderSide(
                        color: bus.isAvailable
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF576238),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteBus(bus.busId),
                    icon: const Icon(Icons.delete, size: 14),
                    label: const Text(
                      'Delete',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showAddBusDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            maxWidth: MediaQuery.of(context).size.width * 0.95,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF576238),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_business,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add New Bus',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Content
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter number plate';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'Driver',
                          value: selectedDriverEmail,
                          items: drivers.map((driver) {
                            return DropdownMenuItem<String>(
                              value: driver['email'] as String,
                              child: Text(
                                driver['name'] as String,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedDriverEmail = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a driver';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildDropdownField(
                          label: 'Vehicle Model',
                          value: selectedVehicleModel,
                          items: vehicleModels.map((model) {
                            return DropdownMenuItem(
                              value: model,
                              child: Text(
                                model,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedVehicleModel = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a vehicle model';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Simplified Route Selection
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
                              Row(
                                children: [
                                  Icon(
                                    Icons.map,
                                    color: const Color(0xFF576238),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Route Selection',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
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
                                        backgroundColor: const Color(
                                            0xFF90EE90), // Light green
                                        foregroundColor:
                                            const Color(0xFF111827),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
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
                                      label: const Text('Select Destination'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                            0xFFFF6B6B), // Light red
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Location display
                              if (_startPointController.text.isNotEmpty ||
                                  _destinationController.text.isNotEmpty) ...[
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
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Start:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF576238),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 20, top: 4),
                                          child: Text(
                                            _startPointController.text,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
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
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Destination:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFDC2626),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 20, top: 4),
                                          child: Text(
                                            _destinationController.text,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Location validation
                        if (_startPointController.text.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFFFEAA7)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: const Color(0xFF856404),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Please select a start location',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF856404),
                                  ),
                                ),
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
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: const Color(0xFF856404),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Please select a destination',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF856404),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _fareController,
                          label: 'Fare (UGX)',
                          hint: '15000',
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Seat Capacity: $constantSeatCapacity seats (fixed for all buses)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _departureTimeController,
                          label: 'Departure Time (Optional)',
                          hint: '2024-01-15T10:00:00',
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              try {
                                DateTime.parse(value);
                              } catch (e) {
                                return 'Please enter valid date format (YYYY-MM-DDTHH:MM:SS)';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
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
                                      Colors.white),
                                ),
                              )
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF576238)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF576238)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewInfo(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF576238)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF576238),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
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
            
            // Only fetch route and show preview if both locations are set
            if (_startLatLng != null && _destinationLatLng != null) {
              setState(() {
                _showPreview = true;
              });
              await _fetchRouteAndServiceArea();
            }
          },
        ),
      ),
    );
  }
}
