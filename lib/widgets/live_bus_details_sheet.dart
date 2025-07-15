import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class LiveBusDetailsSheet extends StatefulWidget {
  final String busId;
  final Map<String, dynamic> booking;
  final BitmapDescriptor? passengerIcon;
  const LiveBusDetailsSheet({
    required this.busId,
    required this.booking,
    this.passengerIcon,
    Key? key,
  }) : super(key: key);

  @override
  State<LiveBusDetailsSheet> createState() => _LiveBusDetailsSheetState();
}

class _LiveBusDetailsSheetState extends State<LiveBusDetailsSheet> {
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
