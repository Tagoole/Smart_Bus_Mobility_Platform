import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:smart_bus_mobility_platform1/screens/nav_bar_screen.dart';
import 'package:smart_bus_mobility_platform1/utils/notification_service.dart';

enum SeatStatus { available, selected, reserved }

class SelectSeatScreen extends StatefulWidget {
  final String? origin;
  final String? destination;
  final String busProvider;
  final String plateNumber;
  final BusModel? busModel;
  final LatLng? pickupLocation;
  final String? pickupAddress;
  final DateTime? departureDate;
  final DateTime? returnDate;
  final int adultCount;
  final int childrenCount;

  const SelectSeatScreen({
    super.key,
    this.origin = 'Batticaloa',
    this.destination = 'Colombo',
    this.busProvider = 'Starck Ride',
    this.plateNumber = 'BHB-3344',
    this.busModel,
    this.pickupLocation,
    this.pickupAddress,
    this.departureDate,
    this.returnDate,
    this.adultCount = 1,
    this.childrenCount = 0,
  });

  @override
  State<SelectSeatScreen> createState() => _SelectSeatScreen();
}

class _SelectSeatScreen extends State<SelectSeatScreen> {
  // Seat management
  Map<int, SeatStatus> seatStatus = {};
  Set<int> selectedSeats = {};
  StreamSubscription<DocumentSnapshot>? _busSubscription;

  // Seat layout configuration
  final int totalSeats = 40;
  final int seatsPerRow = 5; // 2 + 3 seater
  final int totalRows = 8;

  // Trip data
  late String fromCity;
  late String toCity;
  late String fromPlace;
  late String toPlace;

  // Booking state
  bool isBooking = false;
  bool isLoading = true;
  BusModel? currentBusData;

  // Add local state for adults/children
  late int adultCount;
  late int childrenCount;

  // Add timer for live ETA updates
  Timer? _etaTimer;
  String? _currentBookingId;

  @override
  void initState() {
    super.initState();
    fromCity = widget.origin ?? 'Batticaloa';
    toCity = widget.destination ?? 'Colombo';
    fromPlace = 'Originating Place';
    toPlace = 'Destination Place';
    adultCount = widget.adultCount;
    childrenCount = widget.childrenCount;
    _initializeSeats();
    _loadBusData();
    _prefillBookingData();
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  void _initializeSeats() {
    // Initialize all seats as available
    for (int i = 1; i <= totalSeats; i++) {
      seatStatus[i] = SeatStatus.available;
    }
  }

  void _loadBusData() {
    if (widget.busModel == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Listen to real-time updates from the bus document
    _busSubscription = FirebaseFirestore.instance
        .collection('buses')
        .doc(widget.busModel!.busId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final busData = BusModel.fromJson(snapshot.data()!, snapshot.id);
        setState(() {
          currentBusData = busData;
          _updateSeatStatus(busData);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    });
  }

  void _updateSeatStatus(BusModel busData) {
    // Reset all seats to available
    for (int i = 1; i <= totalSeats; i++) {
      seatStatus[i] = SeatStatus.available;
    }

    // Mark booked seats as reserved
    if (busData.bookedSeats != null) {
      for (String seatNumber in busData.bookedSeats!.keys) {
        final seatNum = int.tryParse(seatNumber);
        if (seatNum != null && seatNum <= totalSeats) {
          seatStatus[seatNum] = SeatStatus.reserved;
        }
      }
    }

    // Keep currently selected seats as selected (if they're not reserved)
    for (int seat in selectedSeats) {
      if (seatStatus[seat] == SeatStatus.available) {
        seatStatus[seat] = SeatStatus.selected;
      }
    }
  }

  void _swapLocations() {
    setState(() {
      String tempCity = fromCity;
      String tempPlace = fromPlace;
      fromCity = toCity;
      fromPlace = toPlace;
      toCity = tempCity;
      toPlace = tempPlace;
    });
  }

  void _toggleSeat(int seatNumber) {
    if (seatStatus[seatNumber] == SeatStatus.reserved) return;

    setState(() {
      if (seatStatus[seatNumber] == SeatStatus.selected) {
        seatStatus[seatNumber] = SeatStatus.available;
        selectedSeats.remove(seatNumber);
      } else {
        seatStatus[seatNumber] = SeatStatus.selected;
        selectedSeats.add(seatNumber);
      }
    });
  }

  Color _getSeatColor(int seatNumber) {
    switch (seatStatus[seatNumber]) {
      case SeatStatus.reserved:
        return Colors.green[900]!;
      case SeatStatus.selected:
        return Colors.yellow[600]!;
      default:
        return Colors.white;
    }
  }

  Color _getSeatTextColor(int seatNumber) {
    switch (seatStatus[seatNumber]) {
      case SeatStatus.reserved:
        return Colors.white;
      default:
        return Colors.black;
    }
  }

  Future<void> _confirmBooking() async {
    if (selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one seat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.busModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bus information not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isBooking = true;
    });

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

      // Calculate total fare
      final totalFare = widget.busModel!.fare * (adultCount + childrenCount);

      // Save booking to Firestore
      final bookingRef =
          await FirebaseFirestore.instance.collection('bookings').add({
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'pickupLat': widget.pickupLocation!.latitude, // double
        'pickupLng': widget.pickupLocation!.longitude, // double
        'pickupLocation': widget.pickupAddress, // String
        'destination': widget.destination, // String
        'pickupTime': widget.departureDate != null
            ? Timestamp.fromDate(widget.departureDate!)
            : null, // String or Timestamp
        'busId': widget.busModel!.busId,
        'bus': widget.busModel!.toJson(), // if you want to store bus details
        'pickupLocation': {
          'latitude': widget.pickupLocation!.latitude,
          'longitude': widget.pickupLocation!.longitude,
        },
        'pickupAddress': widget.pickupAddress,
        'departureDate': widget.departureDate != null
            ? Timestamp.fromDate(widget.departureDate!)
            : null,
        'returnDate': widget.returnDate != null
            ? Timestamp.fromDate(widget.returnDate!)
            : null,
        'adultCount': adultCount,
        'childrenCount': childrenCount,
        'selectedSeats': selectedSeats.toList(),
        'totalFare': totalFare,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update the bus's bookedSeats in Firestore
      final busDocRef = FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.busModel!.busId);
      await busDocRef.set({
        'bookedSeats': {
          for (var seat in selectedSeats) seat.toString(): user.uid,
        }
      }, SetOptions(merge: true));

      // Send notification for booking confirmation
      try {
        final notificationService = NotificationService();
        await notificationService.sendBookingConfirmation(
          userId: user.uid,
          bookingId: bookingRef.id,
          destination: widget.destination ?? 'Unknown Destination',
          departureDate: widget.departureDate ?? DateTime.now(),
          amount: totalFare,
        );
      } catch (e) {
        print('Error sending notification: $e');
      }

      // Show the ticket dialog
      _showBookingSuccessDialog(
        bookingRef.id,
        selectedSeats.toList(),
        totalFare,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error booking: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isBooking = false;
      });
    }
  }

  void _showBookingSuccessDialog(
      String bookingId, List<int> selectedSeats, double totalFare) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green[50]!, Colors.white],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Success Title
                  const Text(
                    'Booking Successful!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Booking Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                            'Booking ID', bookingId.substring(0, 8)),
                        _buildDetailRow('Route',
                            '${widget.origin} → ${widget.destination}'),
                        _buildDetailRow('Seats', selectedSeats.join(', ')),
                        _buildDetailRow(
                            'Total Fare', '\$${totalFare.toStringAsFixed(2)}'),
                        _buildDetailRow(
                            'Bus', widget.busModel?.numberPlate ?? ''),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/payment',
                          arguments: {
                            'totalFare': totalFare,
                            'bookingId': bookingId,
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Pay Here',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
        title: const Text(
          'Select Your Seat',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue[100],
              child: const Icon(Icons.person, color: Colors.blue, size: 24),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.yellow[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip Summary Header
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'From',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      fromCity,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      fromPlace,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _swapLocations,
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.swap_horiz,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'To',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      toCity,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      toPlace,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Seat Legend Section
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _buildLegendItem(
                                    color: Colors.green[900]!,
                                    label: 'Reserved',
                                  ),
                                  _buildLegendItem(
                                    color: Colors.white,
                                    label: 'Available',
                                    hasBorder: true,
                                  ),
                                  _buildLegendItem(
                                    color: Colors.yellow[600]!,
                                    label: 'Selected',
                                  ),
                                  _buildDriverLegend(),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Selected seats: ${selectedSeats.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Seat Layout and Driver Section
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              // Driver Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.directions_car,
                                          color: Colors.blue,
                                          size: 16,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Driver',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Seat Layout Grid
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  children: [
                                    // Header showing seat arrangement
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              '2 + 3 Seater',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Seat Grid with 2+3 layout
                                    for (int row = 0; row < totalRows; row++)
                                      _buildSeatRow(row),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Continue Button - Fixed at bottom
              if (selectedSeats.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isBooking ? null : _confirmBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isBooking
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                  'Confirming Booking...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Confirm Booking (${selectedSeats.length} seat${selectedSeats.length > 1 ? 's' : ''})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeatRow(int rowIndex) {
    int startSeat = rowIndex * seatsPerRow + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left side seats (2 seats)
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatWidget(startSeat),
                _buildSeatWidget(startSeat + 1),
              ],
            ),
          ),
          // Aisle space
          const SizedBox(width: 20),
          // Right side seats (3 seats)
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatWidget(startSeat + 2),
                _buildSeatWidget(startSeat + 3),
                _buildSeatWidget(startSeat + 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatWidget(int seatNumber) {
    return GestureDetector(
      onTap: () => _toggleSeat(seatNumber),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _getSeatColor(seatNumber),
          border: Border.all(
            color: seatStatus[seatNumber] == SeatStatus.available
                ? Colors.grey[400]!
                : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          seatNumber.toString(),
          style: TextStyle(
            color: _getSeatTextColor(seatNumber),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool hasBorder = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            border: hasBorder ? Border.all(color: Colors.grey[400]!) : null,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDriverLegend() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.directions_car, size: 16, color: Colors.blue),
        SizedBox(width: 4),
        Text(
          'Driver',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Future<void> _prefillBookingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.busModel == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .where('busId', isEqualTo: widget.busModel!.busId)
        .where('status', isEqualTo: 'confirmed')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final booking = snapshot.docs.first.data();
      setState(() {
        selectedSeats =
            Set<int>.from((booking['selectedSeats'] ?? []).cast<int>());
        // Pre-fill adults/children if not already set
        if (adultCount == 1 && booking['adultCount'] != null) {
          adultCount = booking['adultCount'];
        }
        if (childrenCount == 0 && booking['childrenCount'] != null) {
          childrenCount = booking['childrenCount'];
        }
      });
    }
  }

  Future<String?> _calculateAndSaveETA() async {
    if (widget.busModel == null || widget.pickupLocation == null) return null;
    // Get bus's current location from Firestore
    final busDoc = await FirebaseFirestore.instance
        .collection('buses')
        .doc(widget.busModel!.busId)
        .get();
    if (!busDoc.exists || busDoc.data()?['currentLocation'] == null) {
      return null;
    }
    final location = busDoc.data()!['currentLocation'];
    final busLatLng = LatLng(location['latitude'], location['longitude']);
    final pickupLatLng = widget.pickupLocation!;
    final directions = await DirectionsRepository().getDirections(
      origin: busLatLng,
      destination: pickupLatLng,
    );
    final eta = directions?.totalDuration;
    return eta;
  }

  // Start periodic ETA updates every 50 seconds
  void _startLiveEtaUpdates() {
    _etaTimer?.cancel();
    if (_currentBookingId == null) return;
    _etaTimer = Timer.periodic(Duration(seconds: 50), (_) async {
      final eta = await _calculateAndSaveETA();
      if (eta != null) {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(_currentBookingId)
            .update({'eta': eta, 'updatedAt': FieldValue.serverTimestamp()});
      }
    });
  }
}





