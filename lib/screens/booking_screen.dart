import 'package:flutter/material.dart';
import 'AvailableBus_screen.dart';

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
  List<Map<String, dynamic>> availableBuses = [];
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _departureDateController =
      TextEditingController();
  final TextEditingController _returnDateController = TextEditingController();

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _departureDateController.dispose();
    _returnDateController.dispose();
    super.dispose();
  }

  String formatDate(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}";
  }

  List<Map<String, dynamic>> getSampleBuses() {
    return [
      {
        'busName': 'Express Travels',
        'busNumber': 'EXP-1234',
        'departureTime': '06:00 AM',
        'arrivalTime': '02:00 PM',
        'duration': '8h 00m',
        'price': 850.0,
        'seatsAvailable': 12,
        'rating': 4.5,
        'amenities': ['AC', 'WiFi', 'Charging Port'],
        'busType': 'AC Sleeper',
      },
      {
        'busName': 'Royal Coach',
        'busNumber': 'RC-5678',
        'departureTime': '08:30 AM',
        'arrivalTime': '04:15 PM',
        'duration': '7h 45m',
        'price': 950.0,
        'seatsAvailable': 8,
        'rating': 4.2,
        'amenities': ['AC', 'Entertainment', 'Snacks'],
        'busType': 'AC Semi-Sleeper',
      },
      {
        'busName': 'City Express',
        'busNumber': 'CE-9012',
        'departureTime': '10:00 AM',
        'arrivalTime': '06:30 PM',
        'duration': '8h 30m',
        'price': 750.0,
        'seatsAvailable': 15,
        'rating': 4.0,
        'amenities': ['AC', 'Charging Port'],
        'busType': 'AC Seater',
      },
      {
        'busName': 'Comfort Ride',
        'busNumber': 'CR-3456',
        'departureTime': '02:00 PM',
        'arrivalTime': '10:45 PM',
        'duration': '8h 45m',
        'price': 900.0,
        'seatsAvailable': 6,
        'rating': 4.7,
        'amenities': ['AC', 'WiFi', 'Entertainment', 'Blanket'],
        'busType': 'Luxury AC',
      },
      {
        'busName': 'Speed Line',
        'busNumber': 'SL-7890',
        'departureTime': '11:30 PM',
        'arrivalTime': '07:00 AM',
        'duration': '7h 30m',
        'price': 800.0,
        'seatsAvailable': 20,
        'rating': 3.8,
        'amenities': ['AC', 'Charging Port'],
        'busType': 'AC Sleeper',
      },
    ];
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

  void _findBus() {
    if (fromLocation == "Origin" || toLocation == "Destination") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select origin and destination"),
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

    // Navigate to AvailableBus_screen and pass relevant data if needed
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvailableBus(
          origin: fromLocation,
          destination: toLocation,
          departureDate: departureDate != null
              ? formatDate(departureDate!)
              : '',
          returnDate: returnDate != null ? formatDate(returnDate!) : '',
          isOneWay: !isRoundTrip,
        ),
      ),
    );
  }

  void _bookBus(Map<String, dynamic> bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Book Bus"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bus: ${bus['busName']}"),
            Text("Route: $fromLocation → $toLocation"),
            Text(
              "Date: ${departureDate != null ? formatDate(departureDate!) : 'Not selected'}",
            ),
            Text("Passengers: $adultCount Adults, $childrenCount Children"),
            Text(
              "Total: ₹${(bus['price'] * (adultCount + childrenCount)).toStringAsFixed(0)}",
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Bus booked successfully!"),
                  backgroundColor: Colors.green,
                ),
              );
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
                _buildSearchSection(),
                const SizedBox(height: 20),
                if (showBusList) _buildAvailableBusesList(),
                if (!showBusList) _buildUpcomingTicketSection(),
              ],
            ),
          ),
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
            color: Colors.grey.withOpacity(0.1),
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
                        : Colors.grey[300],
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
                        : Colors.grey[300],
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
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
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
                backgroundColor: Colors.grey[200],
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
                backgroundColor: Colors.grey[200],
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

  Widget _buildBusCard(Map<String, dynamic> bus) {
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
                      bus['busName'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      bus['busNumber'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                    bus['busType'],
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
                        bus['departureTime'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        bus['arrivalTime'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  bus['duration'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.star, color: Colors.orange[400], size: 16),
                const SizedBox(width: 4),
                Text(
                  "${bus['rating']}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "${bus['seatsAvailable']} seats left",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (bus['amenities'] as List<String>).map((amenity) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    amenity,
                    style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "₹${bus['price'].toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      "per person",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.more_vert, color: Colors.grey),
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
