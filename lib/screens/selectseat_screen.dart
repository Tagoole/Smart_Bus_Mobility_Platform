import 'package:flutter/material.dart';

class SeatSelection extends StatefulWidget {
  final String? origin;
  final String? destination;
  final String busProvider;
  final String plateNumber;

  const SeatSelection({
    super.key,
    this.origin,
    this.destination,
    this.busProvider = "Starck Ride",
    this.plateNumber = "BHB-3344",
  });

  @override
  State<SeatSelection> createState() => _SeatSelection();
}

class _SeatSelection extends State<SeatSelection> {
  // Seat status: 0 = available, 1 = reserved, 2 = selected
  Map<int, int> seatStatus = {};
  Set<int> selectedSeats = {};

  // Reserved seats (predefined)
  final Set<int> reservedSeats = {1, 6, 11, 16, 18, 19, 20, 26, 27, 31, 32, 36, 37};

  // Initially selected seats
  final Set<int> initiallySelectedSeats = {5, 21, 28};

  @override
  void initState() {
    super.initState();
    _initializeSeats();
  }

  void _initializeSeats() {
    // Initialize all seats as available
    for (int i = 1; i <= 40; i++) {
      seatStatus[i] = 0; // available
    }

    // Set reserved seats
    for (int seat in reservedSeats) {
      seatStatus[seat] = 1; // reserved
    }

    // Set initially selected seats
    for (int seat in initiallySelectedSeats) {
      seatStatus[seat] = 2; // selected
      selectedSeats.add(seat);
    }
  }

  void _toggleSeat(int seatNumber) {
    if (seatStatus[seatNumber] == 1) {
      // Reserved seat - cannot be selected
      return;
    }

    setState(() {
      if (seatStatus[seatNumber] == 2) {
        // Currently selected - deselect
        seatStatus[seatNumber] = 0;
        selectedSeats.remove(seatNumber);
      } else {
        // Currently available - select
        seatStatus[seatNumber] = 2;
        selectedSeats.add(seatNumber);
      }
    });
  }

  Color _getSeatColor(int seatNumber) {
    switch (seatStatus[seatNumber]) {
      case 1:
        return const Color(0xFF00FF00); // Green for reserved
      case 2:
        return const Color(0xFFFFFF00); // Yellow for selected
      default:
        return const Color(0xFFFFFFFF); // White for available
    }
  }

  Color _getSeatTextColor(int seatNumber) {
    switch (seatStatus[seatNumber]) {
      case 1:
        return Colors.white; // White text on green background
      case 2:
        return Colors.black; // Black text on yellow background
      default:
        return Colors.black; // Black text on white background
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFACD), // Light yellow background
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
            icon: const Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
        ),
        title: const Text(
          'Select your seat',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              child: ClipOval(
                child: Image.asset(
                  'assets/profile_image.jpg',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person,
                      color: Colors.grey,
                      size: 24,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top Section - From/To
            _buildFromToSection(),
            
            const SizedBox(height: 24),
            
            // Legend Section
            _buildLegendSection(),
            
            const SizedBox(height: 16),
            
            // Selected Seats Info
            _buildSelectedSeatsInfo(),
            
            const SizedBox(height: 24),
            
            // Seat Grid
            Expanded(
              child: _buildSeatGrid(),
            ),
            
            const SizedBox(height: 16),
            
            // Continue Button
            _buildContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFromToSection() {
    return Column(
      children: [
        // From/To labels with swap icon
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'From',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 40),
            const Icon(
              Icons.swap_horiz,
              color: Colors.green,
              size: 24,
            ),
            const SizedBox(width: 40),
            const Text(
              'To',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Location names
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.origin ?? 'Originating Place',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 80),
            Text(
              widget.destination ?? 'Destination Place',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem(
          const Color(0xFF00FF00),
          'Reserved',
        ),
        _buildLegendItem(
          const Color(0xFFFFFFFF),
          'Available',
          hasBorder: true,
        ),
        _buildLegendItem(
          const Color(0xFFFFFF00),
          'Selected',
        ),
        _buildDriverLegend(),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: hasBorder ? Border.all(color: Colors.grey) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
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
          color: Colors.black,
        ),
        SizedBox(width: 4),
        Text(
          'Driver',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSelectedSeatsInfo() {
    return Text(
      'Selected seats: ${selectedSeats.length}',
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSeatGrid() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Section - Seat Grid
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSeatsGrid(),
            ),
          ),
          
          // Vertical Divider
          Container(
            width: 1,
            color: Colors.grey[300],
          ),
          
          // Right Section - Driver
          Expanded(
            flex: 1,
            child: Container(
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF00FF00),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatsGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4 seats per row
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: 40,
      itemBuilder: (context, index) {
        int seatNumber = index + 1;
        return _buildSeatWidget(seatNumber);
      },
    );
  }

  Widget _buildSeatWidget(int seatNumber) {
    return GestureDetector(
      onTap: () => _toggleSeat(seatNumber),
      child: Container(
        decoration: BoxDecoration(
          color: _getSeatColor(seatNumber),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            seatNumber.toString(),
            style: TextStyle(
              color: _getSeatTextColor(seatNumber),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: selectedSeats.isNotEmpty ? _proceedToBooking : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Continue with ${selectedSeats.length} seat${selectedSeats.length != 1 ? 's' : ''}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _proceedToBooking() {
    // Show confirmation dialog or navigate to booking confirmation
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
                // Navigate to payment or booking confirmation screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Proceeding to booking confirmation...'),
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
