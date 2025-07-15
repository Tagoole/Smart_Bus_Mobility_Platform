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
      builder: (context) => _LiveBusDetailsSheet(
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
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No booked buses found.'));
                }
                final bookings = snapshot.data!.docs;
                print(
                    '[UI] Loaded ${bookings.length} bookings for Booked Buses screen.');
                return ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: bookings.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final booking =
                        bookings[index].data() as Map<String, dynamic>;
                    print(
                        '[UI] Booked Buses ETA for booking: ${booking['eta']}');
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
                            Text(
                                'Departure: ${_formatDateTime(booking['departureDate'])}'),
                            if (booking['pickupLocation'] != null)
                              Text(
                                  'Pickup: (${booking['pickupLocation']['latitude']?.toStringAsFixed(5)}, ${booking['pickupLocation']['longitude']?.toStringAsFixed(5)})'),
                            Text('ETA: ${booking['eta'] ?? 'Calculating...'}'),
                          ],
                        ),
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

class _LiveBusDetailsSheet extends StatefulWidget {
  final String busId;
  final Map<String, dynamic> booking;
  final BitmapDescriptor? passengerIcon;
  const _LiveBusDetailsSheet(
      {required this.busId, required this.booking, this.passengerIcon});

  @override
  State<_LiveBusDetailsSheet> createState() => _LiveBusDetailsSheetState();
}

class _LiveBusDetailsSheetState extends State<_LiveBusDetailsSheet> {
  Map<String, dynamic>? _bus;
  Map<String, dynamic>? _currentLocation;
  late Stream<DocumentSnapshot> _busStream;

  @override
  void initState() {
    super.initState();
    _busStream = FirebaseFirestore.instance
        .collection('buses')
        .doc(widget.busId)
        .snapshots();
    _busStream.listen((doc) {
      if (doc.exists) {
        setState(() {
          _bus = doc.data() as Map<String, dynamic>?;
          _currentLocation = _bus?['currentLocation'];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bus = _bus;
    final pickupLocation = widget.booking['pickupLocation'];
    final passengerIcon = widget.passengerIcon;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text(
                  bus != null
                      ? '${bus['startPoint']} → ${bus['destination']}'
                      : 'Loading...',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text('Bus Plate: ${bus?['numberPlate'] ?? 'N/A'}'),
            Text(
                'Departure: ${_formatDateTime(widget.booking['departureDate'])}'),
            if (bus != null)
              Container(
                height: 220,
                margin: EdgeInsets.only(top: 16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation != null
                        ? LatLng(_currentLocation!['latitude'] ?? 0.0,
                            _currentLocation!['longitude'] ?? 0.0)
                        : (bus['polyline'] != null &&
                                bus['polyline'] is List &&
                                (bus['polyline'] as List).isNotEmpty)
                            ? LatLng(bus['polyline'][0]['latitude'] ?? 0.0,
                                bus['polyline'][0]['longitude'] ?? 0.0)
                            : LatLng(0, 0),
                    zoom: 13,
                  ),
                  polylines: bus['polyline'] != null && bus['polyline'] is List
                      ? {
                          Polyline(
                            polylineId: PolylineId('route'),
                            color: Colors.green,
                            width: 5,
                            points: (bus['polyline'] as List)
                                .map<LatLng>((p) =>
                                    LatLng(p['latitude'], p['longitude']))
                                .toList(),
                          ),
                        }
                      : {},
                  markers: {
                    if (_currentLocation != null)
                      Marker(
                        markerId: MarkerId('bus_live'),
                        position: LatLng(_currentLocation!['latitude'] ?? 0.0,
                            _currentLocation!['longitude'] ?? 0.0),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueBlue),
                        infoWindow: InfoWindow(title: 'Live Bus Location'),
                      ),
                    if (bus != null &&
                        bus['polyline'] != null &&
                        bus['polyline'] is List &&
                        (bus['polyline'] as List).isNotEmpty)
                      Marker(
                        markerId: MarkerId('start'),
                        position: LatLng(bus['polyline'][0]['latitude'] ?? 0.0,
                            bus['polyline'][0]['longitude'] ?? 0.0),
                        infoWindow: InfoWindow(title: 'Start'),
                      ),
                    if (bus != null &&
                        bus['polyline'] != null &&
                        bus['polyline'] is List &&
                        (bus['polyline'] as List).isNotEmpty)
                      Marker(
                        markerId: MarkerId('end'),
                        position: LatLng(
                            bus['polyline'].last['latitude'] ?? 0.0,
                            bus['polyline'].last['longitude'] ?? 0.0),
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
}
