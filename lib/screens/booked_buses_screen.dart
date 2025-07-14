import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';

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
    final bus = await _fetchBus(busId);
    final pickupLocation = booking['pickupLocation'];
    BitmapDescriptor? passengerIcon;
    if (pickupLocation != null) {
      passengerIcon = await MarkerIcons.passengerIcon;
    }
    if (bus == null) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 16),
              const Text('Bus details not found.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text(
                  '${bus['startPoint']} → ${bus['destination']}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text('Bus Plate: ${bus['numberPlate'] ?? 'N/A'}'),
            Text('Departure: ${_formatDateTime(booking['departureDate'])}'),
            if (bus['polyline'] != null && bus['polyline'] is List)
              Container(
                height: 180,
                margin: EdgeInsets.only(top: 16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      (bus['polyline'][0]['latitude'] ?? 0.0) as double,
                      (bus['polyline'][0]['longitude'] ?? 0.0) as double,
                    ),
                    zoom: 12,
                  ),
                  polylines: {
                    Polyline(
                      polylineId: PolylineId('route'),
                      color: Colors.green,
                      width: 5,
                      points: (bus['polyline'] as List)
                          .map<LatLng>(
                              (p) => LatLng(p['latitude'], p['longitude']))
                          .toList(),
                    ),
                  },
                  markers: {
                    Marker(
                      markerId: MarkerId('start'),
                      position: LatLng(
                        (bus['polyline'][0]['latitude'] ?? 0.0) as double,
                        (bus['polyline'][0]['longitude'] ?? 0.0) as double,
                      ),
                      infoWindow: InfoWindow(title: 'Start'),
                    ),
                    Marker(
                      markerId: MarkerId('end'),
                      position: LatLng(
                        (bus['polyline'].last['latitude'] ?? 0.0) as double,
                        (bus['polyline'].last['longitude'] ?? 0.0) as double,
                      ),
                      infoWindow: InfoWindow(title: 'Destination'),
                    ),
                    if (pickupLocation != null && passengerIcon != null)
                      Marker(
                        markerId: MarkerId('pickup'),
                        position: LatLng(
                          pickupLocation['latitude'] as double,
                          pickupLocation['longitude'] as double,
                        ),
                        icon: passengerIcon,
                        infoWindow: InfoWindow(title: 'Your Pickup Location'),
                      ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  liteModeEnabled: true,
                ),
              ),
          ],
        ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('My Booked Buses'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No booked buses found.'));
          }
          final bookings = snapshot.data!;
          return ListView.separated(
            padding: EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading:
                      Icon(Icons.directions_bus, color: Colors.green, size: 32),
                  title: Text('${booking['route'] ?? ''}'),
                  subtitle: Text(
                      'Departure: ${_formatDateTime(booking['departureDate'])}'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () => _showBookingDetails(context, booking),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
