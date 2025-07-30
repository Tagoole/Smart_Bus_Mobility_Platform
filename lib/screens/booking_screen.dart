import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/resources/bus_service.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:smart_bus_mobility_platform1/models/admin_route_point.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'passenger_map_screen.dart';
import 'selectseat_screen.dart';
import 'package:intl/intl.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_model.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'dart:async'; // Added for Timer and StreamSubscription

void main() {
  runApp(const BusBooking());
}

class BusBooking extends StatelessWidget {
  const BusBooking({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Booking App',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const FindBusScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FindBusScreen extends StatefulWidget {
  const FindBusScreen({super.key});

  @override
  State<FindBusScreen> createState() => _FindBusScreenState();
}

class _FindBusScreenState extends State<FindBusScreen> {
  bool isRoundTrip = false;
  DateTime? departureDate;
  DateTime? returnDate;
  int adultCount = 1;
  int childrenCount = 0;
  bool showBusList = false;
  List<BusModel> availableBuses = [];
  List<BusModel> allActiveBuses = [];
  bool isLoadingBuses = false;
  bool isLoadingAllBuses = false;

  // Pickup location
  LatLng? pickupLocation;
  String pickupAddress = "Select pickup location";

  // Booking state
  BusModel? currentBooking;
  String? bookingId;
  bool hasActiveBooking = false;

  // Selected bus for booking
  BusModel? selectedBus;

  // Fetch route points for the selected bus
  AdminRoutePoint? _startRoutePoint;
  AdminRoutePoint? _destinationRoutePoint;
  bool _isLoadingRoutePoints = false;

  Directions? _routeInfo;
  bool _isLoadingRoute = false;
  GoogleMapController? _mapController;

  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _returnDateController = TextEditingController();

  final BusService _busService = BusService();

  // Automatic refresh mechanisms
  Timer? _busRefreshTimer;
  Timer? _bookingRefreshTimer;
  StreamSubscription<QuerySnapshot>? _busSubscription;
  StreamSubscription<QuerySnapshot>? _bookingSubscription;

  @override
  void initState() {
    super.initState();
    // Check for active bookings
    _checkActiveBookings();
    // Load all active buses for dropdown
    _loadAllActiveBuses();

    // Set up automatic refresh
    _setupAutoRefresh();
  }

  // Set up automatic refresh mechanisms
  void _setupAutoRefresh() {
    // Refresh bus availability every 3 minutes
    Timer.periodic(const Duration(minutes: 3), (timer) {
      if (mounted) {
        _loadAllActiveBuses();
      }
    });

    // Refresh active bookings every 2 minutes
    Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _checkActiveBookings();
      }
    });
  }

  @override
  void dispose() {
    _departureDateController.dispose();
    _returnDateController.dispose();
    super.dispose();
  }

  // Load all active buses for the dropdown
  Future<void> _loadAllActiveBuses() async {
    setState(() {
      isLoadingAllBuses = true;
    });

    try {
      // Get all buses from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('isAvailable', isEqualTo: true)
          .get();

      setState(() {
        allActiveBuses = snapshot.docs.map((doc) {
          final data = doc.data();
          return BusModel.fromJson(data, doc.id);
        }).toList();
        isLoadingAllBuses = false;
      });
    } catch (e) {
      print('Error loading all buses: $e');
      setState(() {
        isLoadingAllBuses = false;
      });
    }
  }

  // Check for active bookings
  Future<void> _checkActiveBookings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'confirmed')
          .where('departureDate', isGreaterThan: DateTime.now())
          .orderBy('departureDate')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final bookingData = snapshot.docs.first.data();
        setState(() {
          hasActiveBooking = true;
          bookingId = snapshot.docs.first.id;
          currentBooking = BusModel.fromJson(
            bookingData['bus'],
            bookingData['busId'] ?? '',
          );
          pickupLocation = LatLng(
            bookingData['pickupLocation']['latitude'],
            bookingData['pickupLocation']['longitude'],
          );
          pickupAddress = bookingData['pickupAddress'] ?? 'Pickup location set';
          departureDate = (bookingData['departureDate'] as Timestamp).toDate();
          adultCount = bookingData['adultCount'] ?? 1;
          childrenCount = bookingData['childrenCount'] ?? 0;
        });
      }
    } catch (e) {
      print('Error checking active bookings: $e');
    }
  }

  String formatDate(DateTime date) {
    // Use a more compact format for mobile screens
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String formatDateCompact(DateTime date) {
    // Even more compact format for very small screens
    return DateFormat('MMM dd').format(date);
  }

  String formatDateFull(DateTime date) {
    // Full format for when there's enough space
    final daySuffix = _getDayOfMonthSuffix(date.day);
    final formatted = DateFormat('EEEE d').format(date) +
        daySuffix +
        DateFormat(' MMMM, yyyy').format(date);
    return formatted;
  }

  String _getDayOfMonthSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  void _selectPickupLocation() async {
    // Navigate to passenger map screen to select pickup location
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PassengerMapScreen(),
      ),
    );

    // Handle the result from the map screen
    if (result != null && result is Map<String, dynamic>) {
      final selectedLocation = result['location'] as LatLng;
      final selectedAddress = result['address'] as String;

      setState(() {
        pickupLocation = selectedLocation;
        pickupAddress = selectedAddress;
      });

      // If this is an update to an existing booking, save it
      if (hasActiveBooking && bookingId != null) {
        await _saveUpdatedPickupLocation();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Pickup location set to: $pickupAddress"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // Update pickup location for existing booking
  Future<void> _updatePickupLocation() async {
    if (currentBooking == null || bookingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No active booking found"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show pickup location selection dialog
    _selectPickupLocation();
  }

  // Save updated pickup location to Firestore
  Future<void> _saveUpdatedPickupLocation() async {
    if (currentBooking == null || bookingId == null || pickupLocation == null) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'pickupLocation': {
          'latitude': pickupLocation!.latitude,
          'longitude': pickupLocation!.longitude,
        },
        'pickupAddress': pickupAddress,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pickup location updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating pickup location: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate(bool isDeparture) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isDeparture) {
          departureDate = picked;
          _departureDateController.text = formatDate(picked);
        } else {
          returnDate = picked;
          _returnDateController.text = formatDate(picked);
        }
      });
    }
  }

  Future<void> _findBus() async {
    if (selectedBus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a bus route"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (pickupLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a pickup location"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (departureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select departure date"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isRoundTrip && returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select return date"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      availableBuses = [selectedBus!];
      showBusList = true;
    });
  }

  void _selectBusForSeatSelection(BusModel bus) {
    // Navigate to seat selection screen with bus details
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectSeatScreen(
          origin: bus.startPoint,
          destination: bus.destination,
          busProvider: bus.vehicleModel,
          plateNumber: bus.numberPlate,
          busModel: bus, // Pass the bus model
          pickupLocation: pickupLocation,
          pickupAddress: pickupAddress,
          departureDate: departureDate,
          returnDate: returnDate,
          adultCount: adultCount,
          childrenCount: childrenCount,
        ),
      ),
    );
  }

  // Fetch route points for the selected bus
  Future<void> _fetchRoutePointsForBus(BusModel? bus) async {
    if (bus == null) {
      setState(() {
        _startRoutePoint = null;
        _destinationRoutePoint = null;
      });
      return;
    }
    setState(() {
      _isLoadingRoutePoints = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_route_points')
          .where('busId', isEqualTo: bus.busId)
          .get();
      AdminRoutePoint? start;
      AdminRoutePoint? dest;
      for (var doc in snapshot.docs) {
        final point = AdminRoutePoint.fromJson(doc.data(), doc.id);
        if (point.type == 'start') start = point;
        if (point.type == 'destination') dest = point;
      }
      setState(() {
        _startRoutePoint = start;
        _destinationRoutePoint = dest;
        _isLoadingRoutePoints = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingRoutePoints = false;
      });
    }
  }

  Future<void> _fetchRoutePolyline(LatLng start, LatLng end) async {
    setState(() {
      _isLoadingRoute = true;
    });
    try {
      final directions = await DirectionsRepository().getDirections(
        origin: start,
        destination: end,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Let's find Your Next Bus",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: const [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green,
              child: Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFACD), Color(0xFFFFE4B5)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Only show the search section and booking flow, not existing bookings
                _buildSearchSection(),
                const SizedBox(height: 20),
                if (showBusList) _buildAvailableBusesList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build active booking section
  Widget _buildActiveBookingSection() {
    if (currentBooking == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0E0E0).withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              SizedBox(width: 8),
              Text(
                "Active Booking",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBookingInfoRow("Bus", currentBooking!.numberPlate),
          _buildBookingInfoRow(
            "Route",
            "${currentBooking!.startPoint} → ${currentBooking!.destination}",
          ),
          _buildBookingInfoRow("Date", formatDateCompact(departureDate!)),
          _buildBookingInfoRow("Pickup", pickupAddress),
          _buildBookingInfoRow(
            "Passengers",
            "$adultCount Adults, $childrenCount Children",
          ),
          _buildBookingInfoRow(
            "Total",
            "UGX ${(currentBooking!.fare * (adultCount + childrenCount)).toStringAsFixed(0)}",
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _updatePickupLocation,
                  icon: const Icon(Icons.edit_location),
                  label: const Text("Update Pickup"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      hasActiveBooking = false;
                      currentBooking = null;
                      bookingId = null;
                      showBusList = false;
                      selectedBus = null;
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Book Another"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF757575),
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMapSection() {
    if (_isLoadingRoutePoints) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    LatLng? start;
    LatLng? end;
    String? startLabel;
    String? endLabel;
    if (_startRoutePoint != null && _destinationRoutePoint != null) {
      start = LatLng(_startRoutePoint!.latitude, _startRoutePoint!.longitude);
      end = LatLng(
        _destinationRoutePoint!.latitude,
        _destinationRoutePoint!.longitude,
      );
      startLabel = 'Start: ${_startRoutePoint!.address}';
      endLabel = 'Destination: ${_destinationRoutePoint!.address}';
    } else if (selectedBus != null &&
        selectedBus!.startLat != null &&
        selectedBus!.startLng != null &&
        selectedBus!.destinationLat != null &&
        selectedBus!.destinationLng != null) {
      start = LatLng(selectedBus!.startLat!, selectedBus!.startLng!);
      end = LatLng(selectedBus!.destinationLat!, selectedBus!.destinationLng!);
      startLabel = 'From: ${selectedBus!.startPoint}';
      endLabel = 'To: ${selectedBus!.destination}';
    }
    if (start == null || end == null) {
      return const SizedBox.shrink();
    }
    // Fetch the route polyline when both points are available
    if (_routeInfo == null && !_isLoadingRoute) {
      _fetchRoutePolyline(start, end);
    }
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
              initialCameraPosition: CameraPosition(target: start, zoom: 12),
              polylines: const {}, // Polyline drawing disabled due to missing polylinePoints in Directions
              markers: {
                Marker(
                  markerId: const MarkerId('start'),
                  position: start,
                  infoWindow: InfoWindow(title: startLabel),
                  icon: MarkerIcons.startMarker,
                ),
                Marker(
                  markerId: const MarkerId('end'),
                  position: end,
                  infoWindow: InfoWindow(title: endLabel),
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
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0E0E0).withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Bus Route',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),

          // Bus Route Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonFormField<BusModel>(
              value: selectedBus,
              hint: const Text('Select a bus route'),
              isExpanded: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              items: allActiveBuses.map((bus) {
                return DropdownMenuItem<BusModel>(
                  value: bus,
                  child: Text(
                    '${bus.startPoint} → ${bus.destination} (${bus.vehicleModel})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (BusModel? value) {
                setState(() {
                  selectedBus = value;
                });
                _fetchRoutePointsForBus(value);
              },
            ),
          ),
          // Show the route map if a bus is selected
          _buildRouteMapSection(),

          // Route Information Display
          if (selectedBus != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE9ECEF)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF576238),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.route,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected Route',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6C757D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selectedBus!.startPoint} → ${selectedBus!.destination}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212529),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selectedBus!.vehicleModel} • ${selectedBus!.seatCapacity} seats',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6C757D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Trip Type Selection
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => isRoundTrip = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        !isRoundTrip ? Colors.green : const Color(0xFF9E9E9E),
                    foregroundColor: !isRoundTrip ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  child: const Text('One way'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => isRoundTrip = true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isRoundTrip ? Colors.green : const Color(0xFF9E9E9E),
                    foregroundColor: isRoundTrip ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                  child: const Text('Round trip'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Date selection - responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              // Use column layout for smaller screens, row for larger screens
              if (constraints.maxWidth < 400) {
                return Column(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Departure Date',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        GestureDetector(
                          onTap: () => _selectDate(true),
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _departureDateController,
                              decoration: const InputDecoration(
                                hintText: 'Select date',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                suffixIcon: Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return Date',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRoundTrip ? Colors.black : Colors.grey,
                          ),
                        ),
                        GestureDetector(
                          onTap: isRoundTrip ? () => _selectDate(false) : null,
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _returnDateController,
                              enabled: isRoundTrip,
                              decoration: InputDecoration(
                                hintText: 'Select date',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                suffixIcon: Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: isRoundTrip ? null : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Departure Date',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          GestureDetector(
                            onTap: () => _selectDate(true),
                            child: AbsorbPointer(
                              child: TextField(
                                controller: _departureDateController,
                                decoration: const InputDecoration(
                                  hintText: 'Select date',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  suffixIcon: Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Return Date',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isRoundTrip ? Colors.black : Colors.grey,
                            ),
                          ),
                          GestureDetector(
                            onTap:
                                isRoundTrip ? () => _selectDate(false) : null,
                            child: AbsorbPointer(
                              child: TextField(
                                controller: _returnDateController,
                                enabled: isRoundTrip,
                                decoration: InputDecoration(
                                  hintText: 'Select date',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  suffixIcon: Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: isRoundTrip ? null : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                _buildPassengerRow(
                  "Adult",
                  adultCount,
                  (count) => setState(() => adultCount = count),
                ),
                const SizedBox(height: 16),
                _buildPassengerRow(
                  "Children",
                  childrenCount,
                  (count) => setState(() => childrenCount = count),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: ElevatedButton(
              onPressed: _findBus,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Text(
                'Find the bus',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectPickupLocation,
                  icon: const Icon(Icons.location_on),
                  label: Text(pickupAddress),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerRow(
    String label,
    int count,
    Function(int) onCountChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            IconButton(
              onPressed: (label == "Adult" && count > 1) ||
                      (label == "Children" && count > 0)
                  ? () => onCountChanged(count - 1)
                  : null,
              icon: const Icon(Icons.remove),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF9E9E9E),
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(32, 32),
              ),
            ),
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text(
                count.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              onPressed: () => onCountChanged(count + 1),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(32, 32),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvailableBusesList() {
    if (isLoadingBuses) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Selected Bus",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  showBusList = false;
                  availableBuses.clear();
                  selectedBus = null;
                });
              },
              child: const Text(
                "Change Route",
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: availableBuses.length,
          itemBuilder: (context, index) {
            final bus = availableBuses[index];
            return _buildBusCard(bus);
          },
        ),
      ],
    );
  }

  Widget _buildBusCard(BusModel bus) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _selectBusForSeatSelection(bus),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.vehicleModel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        bus.numberPlate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${bus.startPoint} → ${bus.destination}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          bus.departureTime != null
                              ? bus.departureTime!.toString().substring(11, 16)
                              : 'TBD',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          bus.estimatedArrival != null
                              ? bus.estimatedArrival!.toString().substring(
                                    11,
                                    16,
                                  )
                              : 'TBD',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${bus.availableSeats} seats left',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "UGX ${bus.fare.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const Text(
                        "per person",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_seat, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Select Seats",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingTicketSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming traveling ticket',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'No upcoming trips',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Select a bus route above to start booking your journey.',
                  style: TextStyle(color: Color(0xFF666666), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}





