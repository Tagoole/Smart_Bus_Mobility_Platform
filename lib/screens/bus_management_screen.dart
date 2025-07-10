import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
// Added import for PassengerMapScreen
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/screens/admin_map_picker_screen.dart';
import 'package:smart_bus_mobility_platform1/models/admin_route_point.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_model.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';

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

  // Add these variables to hold picked locations and addresses
  LatLng? _pickedStartLatLng;
  String? _pickedStartAddress;
  LatLng? _pickedDestinationLatLng;
  String? _pickedDestinationAddress;
  Directions? _routeInfo;
  bool _isLoadingRoute = false;
  GoogleMapController? _mapController;

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
    if (_pickedStartLatLng == null || _pickedStartAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start location on the map'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_pickedDestinationLatLng == null || _pickedDestinationAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a destination on the map'),
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
        'driverId': selectedDriverEmail, // Use email as driver ID
        'routeId': 'auto-generated', // Auto-generated route ID
        'startPoint': _pickedStartAddress,
        'startLat': _pickedStartLatLng!.latitude,
        'startLng': _pickedStartLatLng!.longitude,
        'destination': _pickedDestinationAddress,
        'destinationLat': _pickedDestinationLatLng!.latitude,
        'destinationLng': _pickedDestinationLatLng!.longitude,
        'seatCapacity': constantSeatCapacity,
        'availableSeats': constantSeatCapacity,
        'fare': double.parse(_fareController.text),
        'isAvailable': true,
        'departureTime': _departureTimeController.text.isNotEmpty
            ? DateTime.parse(_departureTimeController.text).toIso8601String()
            : null,
        'estimatedArrival': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final busRef = await _firestore.collection('buses').add(busData);

      // Save start and destination as AdminRoutePoint in Firestore
      final now = DateTime.now();
      final startPoint = AdminRoutePoint(
        id: '',
        busId: busRef.id,
        type: 'start',
        address: _pickedStartAddress!,
        latitude: _pickedStartLatLng!.latitude,
        longitude: _pickedStartLatLng!.longitude,
        createdAt: now,
      );
      final destinationPoint = AdminRoutePoint(
        id: '',
        busId: busRef.id,
        type: 'destination',
        address: _pickedDestinationAddress!,
        latitude: _pickedDestinationLatLng!.latitude,
        longitude: _pickedDestinationLatLng!.longitude,
        createdAt: now,
      );
      await _firestore
          .collection('admin_route_points')
          .add(startPoint.toJson());
      await _firestore
          .collection('admin_route_points')
          .add(destinationPoint.toJson());

      // Clear form
      _formKey.currentState!.reset();
      _numberPlateController.clear();
      _startPointController.clear();
      _destinationController.clear();
      _fareController.clear();
      _departureTimeController.clear();
      setState(() {
        selectedDriverEmail = null;
        selectedVehicleModel = null;
        _pickedStartLatLng = null;
        _pickedStartAddress = null;
        _pickedDestinationLatLng = null;
        _pickedDestinationAddress = null;
      });

      // Reload buses
      await _loadBuses();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
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

  Future<void> _pickAdminLocation({required bool isStart}) async {
    final markerColor = isStart ? Colors.green : Colors.red;
    final instructions = isStart
        ? 'Pick the START location for this bus route'
        : 'Pick the DESTINATION for this bus route';
    final markerIcon = BitmapDescriptor.defaultMarkerWithHue(
      isStart ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
    );
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminMapPickerScreen(
          instructions: instructions,
          markerIcon: markerIcon,
          markerColor: markerColor,
        ),
      ),
    );
    if (result != null &&
        result is Map &&
        result['location'] != null &&
        result['address'] != null) {
      final LatLng latLng = result['location'];
      final String address = result['address'];
      setState(() {
        if (isStart) {
          _pickedStartLatLng = latLng;
          _pickedStartAddress = address;
        } else {
          _pickedDestinationLatLng = latLng;
          _pickedDestinationAddress = address;
        }
      });
    }
  }

  Future<void> _fetchRoutePolyline() async {
    if (_pickedStartLatLng == null || _pickedDestinationLatLng == null) return;
    setState(() {
      _isLoadingRoute = true;
    });
    try {
      final directions = await DirectionsRepository().getDirections(
        origin: _pickedStartLatLng!,
        destination: _pickedDestinationLatLng!,
      );
      setState(() {
        _routeInfo = directions;
        _isLoadingRoute = false;
      });
    } catch (e) {
      print('Error fetching route polyline: $e');
      setState(() {
        _routeInfo = null;
        _isLoadingRoute = false;
      });
    }
  }

  Widget _buildAdminMapPickerButton({
    required String label,
    required String? address,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.map),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
        ),
        if (address != null && address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 4.0),
            child: Text(
              address,
              style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
            ),
          ),
      ],
    );
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
        padding: const EdgeInsets.all(24.0),
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
                    color: const Color(0xFF576238).withOpacity(0.3),
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
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage your fleet of buses',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${buses.length} Buses',
                style: const TextStyle(
                  fontSize: 12,
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bus.isAvailable
              ? const Color(0xFFE8F5E8)
              : const Color(0xFFFEE2E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bus.isAvailable
                        ? const Color(0xFFE8F5E8)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: bus.isAvailable
                        ? const Color(0xFF576238)
                        : const Color(0xFFDC2626),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.numberPlate,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bus.vehicleModel,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bus.isAvailable
                        ? const Color(0xFFE8F5E8)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    bus.isAvailable ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: bus.isAvailable
                          ? const Color(0xFF576238)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Route',
                    '${bus.startPoint} → ${bus.destination}',
                    Icons.route,
                  ),
                ),
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
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: const Color(0xFF6B7280)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Driver',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        Text(
                          driver['name'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleBusAvailability(bus),
                    icon: Icon(
                      bus.isAvailable ? Icons.pause : Icons.play_arrow,
                      size: 16,
                    ),
                    label: Text(bus.isAvailable ? 'Deactivate' : 'Activate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: bus.isAvailable
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF576238),
                      side: BorderSide(
                        color: bus.isAvailable
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF576238),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteBus(bus.busId),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
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
      builder: (context) => AlertDialog(
        title: const Text(
          'Add New Bus',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF111827),
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      child: Text(driver['name'] as String),
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
                    return DropdownMenuItem(value: model, child: Text(model));
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
                Row(
                  children: [
                    Expanded(
                      child: _buildAdminMapPickerButton(
                        label: _pickedStartAddress == null
                            ? 'Set Start on Map'
                            : 'Change Start Location',
                        address: _pickedStartAddress,
                        onTap: () => _pickAdminLocation(isStart: true),
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAdminMapPickerButton(
                        label: _pickedDestinationAddress == null
                            ? 'Set Destination on Map'
                            : 'Change Destination',
                        address: _pickedDestinationAddress,
                        onTap: () => _pickAdminLocation(isStart: false),
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                if (_pickedStartLatLng != null &&
                    _pickedDestinationLatLng != null)
                  Container(
                    height: 220,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          GoogleMap(
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                            },
                            initialCameraPosition: CameraPosition(
                              target: _pickedStartLatLng!,
                              zoom: 12,
                            ),
                            polylines: _routeInfo != null
                                ? {
                                    Polyline(
                                      polylineId: PolylineId('route'),
                                      points: _routeInfo!.polylinePoints
                                          .map(
                                            (e) =>
                                                LatLng(e.latitude, e.longitude),
                                          )
                                          .toList(),
                                      color: Colors.blue,
                                      width: 5,
                                    ),
                                  }
                                : {},
                            markers: {
                              Marker(
                                markerId: MarkerId('start'),
                                position: _pickedStartLatLng!,
                                infoWindow: InfoWindow(
                                  title: 'Start: $_pickedStartAddress',
                                ),
                                icon: MarkerIcons.startMarker,
                              ),
                              Marker(
                                markerId: MarkerId('end'),
                                position: _pickedDestinationLatLng!,
                                infoWindow: InfoWindow(
                                  title:
                                      'Destination: $_pickedDestinationAddress',
                                ),
                                icon: MarkerIcons.endMarker,
                              ),
                            },
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                          ),
                          if (_isLoadingRoute)
                            const Center(child: CircularProgressIndicator()),
                          // Zoom controls
                          MapZoomControls(mapController: _mapController),
                        ],
                      ),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isAddingBus ? null : _addBus,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF576238),
              foregroundColor: Colors.white,
            ),
            child: isAddingBus
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Add Bus'),
          ),
        ],
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
}
