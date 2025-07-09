import 'package:flutter/material.dart';

class AvailableBus extends StatefulWidget {
  final String? origin;
  final String? destination;
  final String? departureDate;
  final String? returnDate;
  final bool isOneWay;

  const AvailableBus({
    super.key,
    this.origin,
    this.destination,
    this.departureDate,
    this.returnDate,
    this.isOneWay = true,
  });

  @override
  State<AvailableBus> createState() => _AvailableBus();
}

class _AvailableBus extends State<AvailableBus> {
  // Controllers for search filter
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _returnDateController = TextEditingController();

  bool _isOneWay = true;
  DateTime? _selectedDepartureDate;
  DateTime? _selectedReturnDate;

  // Sample bus data
  final List<BusInfo> _availableBuses = [
    BusInfo(
      provider: "Starck Ride",
      plateNumber: "BHB-3344",
      departureTime: "7:00PM",
      date: "12/25/23",
      fromLocation: "Batticaloa Main Street, Kampala",
      toLocation: "Colombo Main Street, Colombo",
      busType: "Sleeper (2)",
      duration: "7hr 30min",
      seatNumber: "5",
    ),
    BusInfo(
      provider: "Express Travel",
      plateNumber: "EXP-1122",
      departureTime: "8:30PM",
      date: "12/25/23",
      fromLocation: "Batticaloa Central Station",
      toLocation: "Colombo Fort Railway Station",
      busType: "Semi Sleeper (3)",
      duration: "8hr 15min",
      seatNumber: "12",
    ),
    BusInfo(
      provider: "Comfort Lines",
      plateNumber: "CML-5566",
      departureTime: "6:00AM",
      date: "12/26/23",
      fromLocation: "Batticaloa Bus Terminal",
      toLocation: "Colombo Pettah Bus Stand",
      busType: "AC Seater (4)",
      duration: "7hr 45min",
      seatNumber: "8",
    ),
    BusInfo(
      provider: "Royal Express",
      plateNumber: "REX-9988",
      departureTime: "9:15PM",
      date: "12/25/23",
      fromLocation: "Batticaloa Main Street",
      toLocation: "Colombo Main Street",
      busType: "Luxury Sleeper (2)",
      duration: "7hr 20min",
      seatNumber: "3",
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with passed data
    _originController.text = widget.origin ?? '';
    _destinationController.text = widget.destination ?? '';
    _departureDateController.text = widget.departureDate ?? '';
    _returnDateController.text = widget.returnDate ?? '';
    _isOneWay = widget.isOneWay;
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _departureDateController.dispose();
    _returnDateController.dispose();
    super.dispose();
  }

  // Date picker function
  Future<void> _selectDate(BuildContext context, bool isDeparture) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isDeparture) {
          _selectedDepartureDate = picked;
          _departureDateController.text =
              "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year.toString().substring(2)}";
        } else {
          _selectedReturnDate = picked;
          _returnDateController.text =
              "${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}/${picked.year.toString().substring(2)}";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6D6), // Cream/yellow background
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Filter Box
                      _buildSearchFilterBox(),

                      const SizedBox(height: 24),

                      // Bus List Section
                      _buildBusListSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFFD700), // Gold/yellow
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),

          // Title
          const Expanded(
            child: Text(
              'Available Bus',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF004225), //
              ),
            ),
          ),

          // Profile Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF004225),
            child: ClipOval(
              child: Image.asset(
                'assets/profile_image.jpg',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBox() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 77, 78, 61), // Light cream/yellow
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF004225).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Origin and Destination
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'From',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF004225),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _originController,
                      decoration: const InputDecoration(
                        hintText: 'Originating Place',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'To',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF004225),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _destinationController,
                      decoration: const InputDecoration(
                        hintText: 'Destination Place',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Trip Type Toggle
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isOneWay = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOneWay
                        ? const Color(0xFF004225)
                        : Colors.white,
                    foregroundColor: _isOneWay
                        ? Colors.white
                        : const Color(0xFF004225),
                    side: BorderSide(color: const Color(0xFF004225), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: const Text('One way'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isOneWay = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_isOneWay
                        ? const Color(0xFF004225)
                        : Colors.white,
                    foregroundColor: !_isOneWay
                        ? Colors.white
                        : const Color(0xFF004225),
                    side: BorderSide(color: const Color(0xFF004225), width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: const Text('Round trip'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Date Pickers
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Departure Date',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF004225),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _selectDate(context, true),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _departureDateController,
                          decoration: const InputDecoration(
                            hintText: 'mm/dd/yy',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            suffixIcon: Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Color(0xFF004225),
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Return Date',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isOneWay
                            ? Colors.grey
                            : const Color(0xFF004225),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: _isOneWay
                          ? null
                          : () => _selectDate(context, false),
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _returnDateController,
                          enabled: !_isOneWay,
                          decoration: InputDecoration(
                            hintText: 'mm/dd/yy',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            suffixIcon: Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: _isOneWay
                                  ? Colors.grey
                                  : const Color(0xFF004225),
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bus List',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF004225), // Dark green
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availableBuses.length,
          itemBuilder: (context, index) {
            return _buildBusCard(_availableBuses[index]);
          },
        ),
      ],
    );
  }

  Widget _buildBusCard(BusInfo bus) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider and Plate Number Row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF004225),
                  child: Text(
                    bus.provider[0],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bus.provider,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  bus.plateNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Route and Date Row
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF004225),
                  size: 18,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "${bus.fromLocation} → ${bus.toLocation}",
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF004225),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  bus.date,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.access_time,
                  color: Color(0xFF004225),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  bus.departureTime,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Bus Type, Duration, Seat Row
            Row(
              children: [
                Chip(
                  label: Text(bus.busType),
                  backgroundColor: const Color(0xFFFFF6D6),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF004225),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16, color: Color(0xFF004225)),
                    const SizedBox(width: 2),
                    Text(
                      bus.duration,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF004225),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(
                      Icons.event_seat,
                      size: 16,
                      color: Color(0xFF004225),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "Seat: ${bus.seatNumber}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF004225),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Book Button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to SelectSeatScreen when Book Now is pressed
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => selectseat_screen(
                        busInfo: bus, // Pass the selected bus info if needed
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004225),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Book Now",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

selectseat_screen({required BusInfo busInfo}) {
}

// BusInfo model class
class BusInfo {
  final String provider;
  final String plateNumber;
  final String departureTime;
  final String date;
  final String fromLocation;
  final String toLocation;
  final String busType;
  final String duration;
  final String seatNumber;

  BusInfo({
    required this.provider,
    required this.plateNumber,
    required this.departureTime,
    required this.date,
    required this.fromLocation,
    required this.toLocation,
    required this.busType,
    required this.duration,
    required this.seatNumber,
  });
}
