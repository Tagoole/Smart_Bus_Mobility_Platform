import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:smart_bus_mobility_platform1/models/location_model.dart';

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

  @override
  void initState() {
    super.initState();
    fromCity = widget.origin ?? 'Batticaloa';
    toCity = widget.destination ?? 'Colombo';
    fromPlace = 'Originating Place';
    toPlace = 'Destination Place';
    _initializeSeats();
    _loadBusData();
  }

  @override
  void dispose() {
    _busSubscription?.cancel();
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
      final totalFare =
          widget.busModel!.fare * (widget.adultCount + widget.childrenCount);

      // Save booking to Firestore
      final bookingData = {
        'userId': user.uid,
        'bus': widget.busModel!.toJson(),
        'busId': widget.busModel!.busId,
        'origin': widget.origin,
        'destination': widget.destination,
        'pickupLocation': widget.pickupLocation != null
            ? {
                'latitude': widget.pickupLocation!.latitude,
                'longitude': widget.pickupLocation!.longitude,
              }
            : null,
        'pickupAddress': widget.pickupAddress,
        'departureDate': widget.departureDate != null
            ? Timestamp.fromDate(widget.departureDate!)
            : null,
        'returnDate': widget.returnDate != null
            ? Timestamp.fromDate(widget.returnDate!)
            : null,
        'adultCount': widget.adultCount,
        'childrenCount': widget.childrenCount,
        'selectedSeats': selectedSeats.toList(),
        'totalFare': totalFare,
        'status': 'confirmed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('bookings')
          .add(bookingData);

      // Update bus available seats and bookedSeats
      final busRef = FirebaseFirestore.instance
          .collection('buses')
          .doc(widget.busModel!.busId);

      // Get the latest bookedSeats map
      final busSnapshot = await busRef.get();
      Map<String, dynamic> bookedSeats = {};
      if (busSnapshot.exists &&
          busSnapshot.data() != null &&
          busSnapshot.data()!.containsKey('bookedSeats')) {
        bookedSeats = Map<String, dynamic>.from(
          busSnapshot.data()!['bookedSeats'] ?? {},
        );
      }
      // Add the new bookings
      for (int seat in selectedSeats) {
        bookedSeats[seat.toString()] = user.uid;
      }

      await busRef.update({
        'availableSeats':
            (busSnapshot.data()?['availableSeats'] ??
                widget.busModel!.seatCapacity) -
            selectedSeats.length,
        'bookedSeats': bookedSeats,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Return booking result
      // After booking is successful, also save the pickup location as active
      if (widget.pickupLocation != null && user != null) {
        // Deactivate old locations
        final existingLocations = await FirebaseFirestore.instance
            .collection('pickup_locations')
            .where('userId', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .get();
        for (var doc in existingLocations.docs) {
          await doc.reference.update({'isActive': false});
        }
        // Save new active pickup location
        final locationModel = LocationModel.createPickupLocation(
          userId: user.uid,
          latitude: widget.pickupLocation!.latitude,
          longitude: widget.pickupLocation!.longitude,
          locationName: 'Pickup Location',
          notes: 'Added on ${DateTime.now().toString()}',
        );
        await FirebaseFirestore.instance
            .collection('pickup_locations')
            .add(locationModel.toJson());
      }

      Navigator.pop(context, {
        'bookingId': docRef.id,
        'selectedSeats': selectedSeats.toList(),
        'totalFare': totalFare,
        'success': true,
      });
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
                            ),
                            Text(
                              fromPlace,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
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
                            ),
                            Text(
                              toPlace,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
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
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
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

              // Continue Button
              if (selectedSeats.isNotEmpty)
                SizedBox(
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
          _buildSeatWidget(startSeat),
          _buildSeatWidget(startSeat + 1),
          // Aisle space
          const SizedBox(width: 40),
          // Right side seats (3 seats)
          _buildSeatWidget(startSeat + 2),
          _buildSeatWidget(startSeat + 3),
          _buildSeatWidget(startSeat + 4),
        ],
      ),
    );
  }

  Widget _buildSeatWidget(int seatNumber) {
    return GestureDetector(
      onTap: () => _toggleSeat(seatNumber),
      child: Container(
        width: 45,
        height: 45,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _getSeatColor(seatNumber),
          border: Border.all(
            color: seatStatus[seatNumber] == SeatStatus.available
                ? Colors.grey[400]!
                : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
            fontSize: 12,
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
}
