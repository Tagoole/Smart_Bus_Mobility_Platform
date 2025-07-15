import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:smart_bus_mobility_platform1/widgets/live_bus_details_sheet.dart';

class BookedBusesScreen extends StatefulWidget {
  const BookedBusesScreen({super.key});

  @override
  _BookedBusesScreenState createState() => _BookedBusesScreenState();
}

class _BookedBusesScreenState extends State<BookedBusesScreen> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _fetchBookings();
  }

  Future<List<Map<String, dynamic>>> _fetchBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .where('departureDate', isGreaterThan: DateTime.now())
        .orderBy('departureDate')
        .get();
    List<Map<String, dynamic>> bookings = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      data['id'] = doc.id;
      bookings.add(data);
    }
    return bookings;
  }

  Future<Map<String, dynamic>?> _fetchBus(String busId) async {
    final doc =
        await FirebaseFirestore.instance.collection('buses').doc(busId).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return data;
  }

  void _showBookingDetails(
      BuildContext context, Map<String, dynamic> booking) async {
    final busId = booking['busId'];
    final pickupLocation = booking['pickupLocation'];
    BitmapDescriptor? passengerIcon;
    if (pickupLocation != null) {
      passengerIcon = await MarkerIcons.passengerIcon;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => LiveBusDetailsSheet(
        busId: busId,
        booking: booking,
        passengerIcon: passengerIcon,
      ),
    );
  }

  String _formatDateTime(dynamic date) {
    if (date is Timestamp) {
      return DateFormat('MMM d, yyyy – HH:mm').format(date.toDate());
    } else if (date is DateTime) {
      return DateFormat('MMM d, yyyy – HH:mm').format(date);
    } else if (date is String) {
      return date;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    print(
        '[DEBUG] BookedBusesScreen build called--------------------------------------------------------------');
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('My Booked Buses'),
      ),
      body: user == null
          ? Center(child: Text('Not logged in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('userId', isEqualTo: user.uid)
                  .where('departureDate', isGreaterThan: DateTime.now())
                  .orderBy('departureDate')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('[DEBUG] Error loading bookings: ${snapshot.error}');
                  return Center(child: Text('Error loading bookings.'));
                }
                if (!snapshot.hasData) {
                  print('[DEBUG] Waiting for bookings data...');
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  print('[DEBUG] No booked buses found.');
                  return Center(child: Text('No booked buses found.'));
                }
                final bookings = snapshot.data!.docs;
                print(
                    '[DEBUG] Loaded ${bookings.length} bookings for Booked Buses screen.');
                return ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: bookings.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final booking =
                        bookings[index].data() as Map<String, dynamic>;
                    print('[DEBUG] Booking tapped:  ${booking['busId']}');
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _fetchBus(booking['busId']),
                      builder: (context, busSnapshot) {
                        final bus = busSnapshot.data;
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(Icons.directions_bus,
                                color: Colors.green, size: 32),
                            title: Text(
                                '${booking['destination'] ?? booking['route'] ?? ''}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Departure:  ${_formatDateTime(booking['departureDate'])}'),
                                if (booking['pickupLocation'] != null)
                                  Text(
                                      'Pickup: (${booking['pickupLocation']['latitude']?.toStringAsFixed(5)}, ${booking['pickupLocation']['longitude']?.toStringAsFixed(5)})'),
                                Text('ETA: ${booking['eta'] ?? 'Calculating...'}'),
                                if (bus != null)
                                  Text('Bus Plate: ${bus['numberPlate'] ?? 'N/A'}'),
                                if (bus != null && bus['driverName'] != null)
                                  Text('Driver: ${bus['driverName']}'),
                                if (booking['totalFare'] != null)
                                  Text('Fare: UGX ${booking['totalFare']}'),
                              ],
                            ),
                            trailing: Icon(Icons.arrow_forward_ios, size: 18),
                            onTap: () {
                              print(
                                  '[DEBUG] Booking details tapped for busId: ${booking['busId']}');
                              _showBookingDetails(context, booking);
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
