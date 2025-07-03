import 'package:flutter/material.dart';

enum SeatStatus { available, selected, reserved }

class SelectSeatScreen extends StatefulWidget {
  final String? origin;
  final String? destination;
  final String busProvider;
  final String plateNumber;

  const SelectSeatScreen({
    super.key,
    this.origin = 'Batticaloa',
    this.destination = 'Colombo',
    this.busProvider = 'Starck Ride',
    this.plateNumber = 'BHB-3344',
  });

  @override
  State<SelectSeatScreen> createState() => _SelectSeatScreen();
}

class _SelectSeatScreen extends State<SelectSeatScreen> {
  // Seat management
  Map<int, SeatStatus> seatStatus = {};
  Set<int> selectedSeats = {};
  final Set<int> reservedSeats = {1, 3, 6, 7, 11, 12, 16, 18, 19, 20, 25, 26, 27, 31, 32, 36, 37};
  final Set<int> initiallySelectedSeats = {5, 21, 28};

  // Seat layout configuration
  final int totalSeats = 40;
  final int seatsPerRow = 5; // 2 + 3 seater
  final int totalRows = 8;

  // Trip data
  late String fromCity;
  late String toCity;
  late String fromPlace;
  late String toPlace;

  @override
  void initState() {
    super.initState();
    fromCity = widget.origin ?? 'Batticaloa';
    toCity = widget.destination ?? 'Colombo';
    fromPlace = 'Originating Place';
    toPlace = 'Destination Place';
    _initializeSeats();
  }

  void _initializeSeats() {
    for (int i = 1; i <= totalSeats; i++) {
      seatStatus[i] = SeatStatus.available;
    }
    for (int seat in reservedSeats) {
      seatStatus[seat] = SeatStatus.reserved;
    }
    for (int seat in initiallySelectedSeats) {
      if (!reservedSeats.contains(seat)) {
        seatStatus[seat] = SeatStatus.selected;
        selectedSeats.add(seat);
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    onPressed: _proceedToBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue (${selectedSeats.length} seat${selectedSeats.length > 1 ? 's' : ''})',
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
            color: seatStatus[seatNumber] == SeatStatus.available ? Colors.grey[400]! : Colors.transparent,
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDriverLegend() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.directions_car,
          size: 16,
          color: Colors.blue,
        ),
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

  void _proceedToBooking() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seat Selection Confirmed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bus: ${widget.busProvider} ${widget.plateNumber}'),
              const SizedBox(height: 8),
              Text('Selected Seats: ${selectedSeats.toList()..sort()}'),
              const SizedBox(height: 8),
              Text('Total Seats: ${selectedSeats.length}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected seats: ${selectedSeats.join(', ')}'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Booking'),
            ),
          ],
        );
      },
    );
  }
}