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
    final eta = widget.booking['eta'];
    
    // Prepare polyline between bus and pickup location
    List<LatLng> busToPickupPolyline = [];
    if (_currentLocation != null && pickupLocation != null) {
      busToPickupPolyline = [
        LatLng(_currentLocation!['latitude'] ?? 0.0, _currentLocation!['longitude'] ?? 0.0),
        LatLng(pickupLocation['latitude'] as double, pickupLocation['longitude'] as double),
      ];
    }

    // Determine initial camera position
    LatLng initialCameraTarget = LatLng(0, 0);
    if (_currentLocation != null) {
      initialCameraTarget = LatLng(_currentLocation!['latitude'] ?? 0.0, _currentLocation!['longitude'] ?? 0.0);
    } else if (pickupLocation != null) {
      initialCameraTarget = LatLng(pickupLocation['latitude'] as double, pickupLocation['longitude'] as double);
    }

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
            Text('Departure:  ${_formatDateTime(widget.booking['departureDate'])}'),
            if (eta != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                child: Text('ETA: $eta', style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
              ),
            if (_currentLocation != null && pickupLocation != null)
              Container(
                height: 220,
                margin: EdgeInsets.only(top: 16),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialCameraTarget,
                    zoom: 13,
                  ),
                  polylines: busToPickupPolyline.length == 2
                      ? {
                          Polyline(
                            polylineId: PolylineId('bus_to_pickup'),
                            color: Colors.green,
                            width: 5,
                            points: busToPickupPolyline,
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
            if (_currentLocation == null || pickupLocation == null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Bus or pickup location not available for map preview.', style: TextStyle(color: Colors.red)),
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

