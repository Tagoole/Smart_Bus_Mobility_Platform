import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/resources/bus_service.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'passenger_map_screen.dart';

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
  String fromLocation = "Origin";
  String fromSubtext = "Originating Place";
  String toLocation = "Destination";
  String toSubtext = "Destination Place";
  bool showBusList = false;
  List<BusModel> availableBuses = [];
  bool isLoadingBuses = false;

  // Pickup location
  LatLng? pickupLocation;
  String pickupAddress = "Select pickup location";

  // Booking state
  BusModel? currentBooking;
  String? bookingId;
  bool hasActiveBooking = false;

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _returnDateController = TextEditingController();

  final BusService _busService = BusService();

  @override
  void initState() {
    super.initState();
    // Create sample buses for testing
    _createSampleBuses();
    // Check for active bookings
    _checkActiveBookings();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _departureDateController.dispose();
    _returnDateController.dispose();
    super.dispose();
  }

  Future<void> _createSampleBuses() async {
    await _busService.createSampleBuses();
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
          fromLocation = bookingData['origin'] ?? 'Origin';
          toLocation = bookingData['destination'] ?? 'Destination';
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
    return "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}";
  }

  void _selectPickupLocation() async {
    // Navigate to passenger map screen to select pickup location
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PassengerMapScreen(isPickupSelection: true),
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

  void _openMapForPickupLocation() {
    // This method is no longer needed since we navigate directly to the map
    // Keeping it for backward compatibility but it won't be used
  }

  // Update pickup location for existing booking
  Future<void> _updatePickupLocation() async {
    if (currentBooking == null || bookingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
        SnackBar(
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

  void _selectLocation(bool isFrom) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFrom ? "Select Origin" : "Select Destination"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Kampala"),
              subtitle: const Text("Capital City"),
              onTap: () {
                setState(() {
                  if (isFrom) {
                    fromLocation = "Kampala";
                    fromSubtext = "Capital City";
                    _originController.text = "Kampala";
                  } else {
                    toLocation = "Kampala";
                    toSubtext = "Capital City";
                    _destinationController.text = "Kampala";
                  }
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("Entebbe"),
              subtitle: const Text("International Airport"),
              onTap: () {
                setState(() {
                  if (isFrom) {
                    fromLocation = "Entebbe";
                    fromSubtext = "International Airport";
                    _originController.text = "Entebbe";
                  } else {
                    toLocation = "Entebbe";
                    toSubtext = "International Airport";
                    _destinationController.text = "Entebbe";
                  }
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("Jinja"),
              subtitle: const Text("Source of the Nile"),
              onTap: () {
                setState(() {
                  if (isFrom) {
                    fromLocation = "Jinja";
                    fromSubtext = "Source of the Nile";
                    _originController.text = "Jinja";
                  } else {
                    toLocation = "Jinja";
                    toSubtext = "Source of the Nile";
                    _destinationController.text = "Jinja";
                  }
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text("Mukono"),
              subtitle: const Text("University Town"),
              onTap: () {
                setState(() {
                  if (isFrom) {
                    fromLocation = "Mukono";
                    fromSubtext = "University Town";
                    _originController.text = "Mukono";
                  } else {
                    toLocation = "Mukono";
                    toSubtext = "University Town";
                    _destinationController.text = "Mukono";
                  }
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _swapLocations() {
    setState(() {
      String tempLocation = fromLocation;
      String tempSubtext = fromSubtext;
      String tempController = _originController.text;
      fromLocation = toLocation;
      fromSubtext = toSubtext;
      _originController.text = _destinationController.text;
      toLocation = tempLocation;
      toSubtext = tempSubtext;
      _destinationController.text = tempController;
    });
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
    if (fromLocation == "Origin" || toLocation == "Destination") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select origin and destination"),
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
      isLoadingBuses = true;
    });

    try {
      // Get available buses based on destination
      List<BusModel> buses = await _busService.getBusesByDestination(
        toLocation,
      );

      setState(() {
        availableBuses = buses;
        showBusList = true;
        isLoadingBuses = false;
      });

      if (buses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No buses available for $toLocation"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isLoadingBuses = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error finding buses: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _bookBus(BusModel bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Book Bus"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bus: ${bus.numberPlate}"),
            Text("Route: ${bus.startPoint} → ${bus.destination}"),
            Text("Pickup: $pickupAddress"),
            Text(
              "Date: ${departureDate != null ? formatDate(departureDate!) : 'Not selected'}",
            ),
            Text("Passengers: $adultCount Adults, $childrenCount Children"),
            Text(
              "Total: UGX ${(bus.fare * (adultCount + childrenCount)).toStringAsFixed(0)}",
            ),
            SizedBox(height: 8),
            Text(
              "Departure: ${bus.departureTime?.toString().substring(11, 16) ?? 'TBD'}",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              "Available Seats: ${bus.availableSeats}",
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmBooking(bus);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              "Confirm Booking",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBooking(BusModel bus) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please login to book a bus"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      bool success = await _busService.bookSeat(
        bus.busId,
        user.uid,
        pickupLocation!,
      );

      if (success) {
        // Save booking to Firestore
        final bookingData = {
          'userId': user.uid,
          'bus': bus.toJson(),
          'origin': fromLocation,
          'destination': toLocation,
          'pickupLocation': {
            'latitude': pickupLocation!.latitude,
            'longitude': pickupLocation!.longitude,
          },
          'pickupAddress': pickupAddress,
          'departureDate': Timestamp.fromDate(departureDate!),
          'returnDate': returnDate != null
              ? Timestamp.fromDate(returnDate!)
              : null,
          'adultCount': adultCount,
          'childrenCount': childrenCount,
          'totalFare': bus.fare * (adultCount + childrenCount),
          'status': 'confirmed',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final docRef = await FirebaseFirestore.instance
            .collection('bookings')
            .add(bookingData);

        setState(() {
          hasActiveBooking = true;
          bookingId = docRef.id;
          currentBooking = bus;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bus booked successfully!"),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to booking confirmation or payment screen
        // Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Booking failed. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
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
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.green,
              child: const Icon(Icons.person, color: Colors.white, size: 24),
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
                if (hasActiveBooking) _buildActiveBookingSection(),
                if (!hasActiveBooking) _buildSearchSection(),
                const SizedBox(height: 20),
                if (showBusList && !hasActiveBooking)
                  _buildAvailableBusesList(),
                if (!showBusList && !hasActiveBooking)
                  _buildUpcomingTicketSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build active booking section
  Widget _buildActiveBookingSection() {
    if (currentBooking == null) return SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFE0E0E0).withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          SizedBox(height: 16),
          _buildBookingInfoRow("Bus", currentBooking!.numberPlate),
          _buildBookingInfoRow("Route", "$fromLocation → $toLocation"),
          _buildBookingInfoRow("Date", formatDate(departureDate!)),
          _buildBookingInfoRow("Pickup", pickupAddress),
          _buildBookingInfoRow(
            "Passengers",
            "$adultCount Adults, $childrenCount Children",
          ),
          _buildBookingInfoRow(
            "Total",
            "UGX ${(currentBooking!.fare * (adultCount + childrenCount)).toStringAsFixed(0)}",
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _updatePickupLocation,
                  icon: Icon(Icons.edit_location),
                  label: Text("Update Pickup"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      hasActiveBooking = false;
                      currentBooking = null;
                      bookingId = null;
                      showBusList = false;
                    });
                  },
                  icon: Icon(Icons.add),
                  label: Text("Book Another"),
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
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF757575),
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
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
            color: Color(0xFFE0E0E0).withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectLocation(true),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'From',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                      TextField(
                        controller: _originController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: fromSubtext,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _swapLocations,
                icon: const Icon(Icons.swap_horiz, color: Colors.green),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectLocation(false),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                      TextField(
                        controller: _destinationController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: toSubtext,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => isRoundTrip = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !isRoundTrip
                        ? Colors.green
                        : const Color(0xFF9E9E9E),
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
                    backgroundColor: isRoundTrip
                        ? Colors.green
                        : const Color(0xFF9E9E9E),
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
          Row(
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
                            hintText: 'mm/dd/yy',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            suffixIcon: Icon(Icons.calendar_today, size: 16),
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
                      onTap: isRoundTrip ? () => _selectDate(false) : null,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _returnDateController,
                          enabled: isRoundTrip,
                          decoration: InputDecoration(
                            hintText: 'mm/dd/yy',
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
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE0E0E0)),
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
                  icon: Icon(Icons.location_on),
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
              onPressed:
                  (label == "Adult" && count > 1) ||
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
              onPressed: count < 10 ? () => onCountChanged(count + 1) : null,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF9E9E9E),
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
      return Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Available Buses (${availableBuses.length})",
              style: const TextStyle(
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
                });
              },
              child: const Text(
                "Clear",
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
                      style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
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
                    bus.startPoint + ' → ' + bus.destination,
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
                            ? bus.estimatedArrival!.toString().substring(11, 16)
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
                  style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
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
                    Text(
                      "per person",
                      style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _bookBus(bus),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Book Now",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.green,
                      child: const Text(
                        'BHB-3344',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Kampala → Jinja',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Departure: 07/10/25, 10:00 AM',
                            style: TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.more_vert, color: Color(0xFF757575)),
                  ],
                ),
                const Divider(height: 32, thickness: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Seat: 12A',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Price: UGX 25,000',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Ticket cancelled"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Ticket Details"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text("Route: Kampala → Jinja"),
                                Text("Date: 07/10/25"),
                                Text("Time: 10:00 AM"),
                                Text("Seat: 12A"),
                                Text("Price: UGX 25,000"),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Close"),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.remove_red_eye,
                        color: Colors.green,
                      ),
                      label: const Text(
                        'View',
                        style: TextStyle(color: Colors.green),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[50],
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
