import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';

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
  bool isLoading = true;
  bool isAddingBus = false;

  // Form controllers for adding new bus
  final _formKey = GlobalKey<FormState>();
  final _numberPlateController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _driverIdController = TextEditingController();
  final _routeIdController = TextEditingController();
  final _startPointController = TextEditingController();
  final _destinationController = TextEditingController();
  final _seatCapacityController = TextEditingController();
  final _fareController = TextEditingController();
  final _departureTimeController = TextEditingController();

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
    _loadBuses();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _numberPlateController.dispose();
    _vehicleModelController.dispose();
    _driverIdController.dispose();
    _routeIdController.dispose();
    _startPointController.dispose();
    _destinationController.dispose();
    _seatCapacityController.dispose();
    _fareController.dispose();
    _departureTimeController.dispose();
    super.dispose();
  }

  Future<void> _loadBuses() async {
    try {
      final snapshot = await _firestore.collection('buses').get();
      setState(() {
        buses = snapshot.docs.map((doc) {
          final data = doc.data();
          return BusModel.fromJson(data, doc.id);
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading buses: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _addBus() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isAddingBus = true;
    });

    try {
      final busData = {
        'numberPlate': _numberPlateController.text.trim(),
        'vehicleModel': _vehicleModelController.text.trim(),
        'driverId': _driverIdController.text.trim(),
        'routeId': _routeIdController.text.trim(),
        'startPoint': _startPointController.text.trim(),
        'destination': _destinationController.text.trim(),
        'seatCapacity': int.parse(_seatCapacityController.text),
        'availableSeats': int.parse(_seatCapacityController.text),
        'fare': double.parse(_fareController.text),
        'isAvailable': true,
        'departureTime': _departureTimeController.text.isNotEmpty
            ? DateTime.parse(_departureTimeController.text).toIso8601String()
            : null,
        'estimatedArrival': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('buses').add(busData);

      // Clear form
      _formKey.currentState!.reset();
      _numberPlateController.clear();
      _vehicleModelController.clear();
      _driverIdController.clear();
      _routeIdController.clear();
      _startPointController.clear();
      _destinationController.clear();
      _seatCapacityController.clear();
      _fareController.clear();
      _departureTimeController.clear();

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
                _buildTextField(
                  controller: _vehicleModelController,
                  label: 'Vehicle Model',
                  hint: 'Toyota Coaster',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter vehicle model';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _driverIdController,
                        label: 'Driver ID',
                        hint: 'DRV001',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter driver ID';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _routeIdController,
                        label: 'Route ID',
                        hint: 'RT001',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter route ID';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _startPointController,
                        label: 'Start Point',
                        hint: 'Kampala',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter start point';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _destinationController,
                        label: 'Destination',
                        hint: 'Entebbe',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter destination';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _seatCapacityController,
                        label: 'Seat Capacity',
                        hint: '30',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter capacity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
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
                    ),
                  ],
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
}
