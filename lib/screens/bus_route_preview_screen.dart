import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/screens/booked_buses_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/selectseat_screen.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';

class BusRoutePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> bus;
  const BusRoutePreviewScreen({super.key, required this.bus});

  @override
  State<BusRoutePreviewScreen> createState() => _BusRoutePreviewScreenState();
}

class _BusRoutePreviewScreenState extends State<BusRoutePreviewScreen> {
  LatLng? _selectedPickup;
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;

  List<LatLng> get polylinePoints {
    final poly = widget.bus['routePolyline'] as List?;
    if (poly == null) return [];
    return poly.map((p) => LatLng(p['lat'], p['lng'])).toList();
  }

  List<LatLng> get polygonPoints {
    // Use the first and last points of the polyline as start and destination
    final points = polylinePoints;
    if (points.length < 2) return [];
    final start = points.first;
    final end = points.last;
    // Find min/max lat/lng
    final minLat =
        start.latitude < end.latitude ? start.latitude : end.latitude;
    final maxLat =
        start.latitude > end.latitude ? start.latitude : end.latitude;
    final minLng =
        start.longitude < end.longitude ? start.longitude : end.longitude;
    final maxLng =
        start.longitude > end.longitude ? start.longitude : end.longitude;
    // Add a small padding to make the rectangle a bit larger
    const padding = 0.005; // ~500m
    return [
      LatLng(minLat - padding, minLng - padding), // bottom left
      LatLng(minLat - padding, maxLng + padding), // bottom right
      LatLng(maxLat + padding, maxLng + padding), // top right
      LatLng(maxLat + padding, minLng - padding), // top left
    ];
  }

  bool isWithinPolygon(LatLng point) {
    final rect = polygonPoints;
    if (rect.length != 4) return false;
    final minLat = rect[0].latitude;
    final maxLat = rect[2].latitude;
    final minLng = rect[0].longitude;
    final maxLng = rect[1].longitude;
    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLng &&
        point.longitude <= maxLng;
  }

  void _onMapTap(LatLng latLng) {
    if (polygonPoints.isNotEmpty && !isWithinPolygon(latLng)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Pickup must be within the service area polygon.')),
      );
      return;
    }
    setState(() {
      _selectedPickup = latLng;
    });
  }

  void _savePickupAndShowBus() async {
    if (_selectedPickup == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please login to book a bus')),
      );
      return;
    }
    final bus = widget.bus;
    final busId = bus['busId'] ?? bus['id'];
    final driverId = bus['driverId'];
    final startLat = bus['startLat'];
    final startLng = bus['startLng'];
    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': user.uid,
        'busId': busId,
        'driverId': driverId,
        'pickupLocation': {
          'latitude': _selectedPickup!.latitude,
          'longitude': _selectedPickup!.longitude,
        },
        'bookingTime': FieldValue.serverTimestamp(),
        'status': 'confirmed',
      });
      setState(() {
        _showBusMarker = true;
        _busStartLatLng = (startLat != null && startLng != null)
            ? LatLng(startLat, startLng)
            : null;
      });
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 12),
              Text('Booking Confirmed!',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              'Your pickup location has been saved and your bus is booked. Proceed to select the number of people and seats.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close preview screen
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SelectSeatScreen(
                      origin: bus['startPoint'],
                      destination: bus['destination'],
                      busProvider: bus['vehicleModel'] ?? '',
                      plateNumber: bus['numberPlate'] ?? '',
                      busModel: BusModel.fromJson(
                          bus, bus['busId'] ?? bus['id'] ?? ''),
                      pickupLocation: _selectedPickup,
                      pickupAddress: '',
                      departureDate: null,
                      returnDate: null,
                      adultCount: 1,
                      childrenCount: 0,
                    ),
                  ),
                );
              },
              child: Text('Continue'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving booking: $e')),
      );
    }
  }

  bool _showBusMarker = false;
  LatLng? _busStartLatLng;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Route & Select Pickup'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a pickup location...',
                suffixIcon: Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (value) async {
                // Optionally implement search using geocoding APIs
                // For now, just show a snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Search not implemented in preview.')),
                );
              },
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target: polylinePoints.isNotEmpty
                    ? polylinePoints[0]
                    : LatLng(0, 0),
                zoom: 13,
              ),
              polylines: {
                if (polylinePoints.isNotEmpty)
                  Polyline(
                    polylineId: PolylineId('route'),
                    color: Colors.green,
                    width: 5,
                    points: polylinePoints,
                  ),
              },
              polygons: {
                if (polygonPoints.isNotEmpty)
                  Polygon(
                    polygonId: PolygonId('service_area'),
                    points: polygonPoints,
                    fillColor: Colors.blue.withOpacity(0.2),
                    strokeColor: Colors.blue,
                    strokeWidth: 2,
                  ),
              },
              markers: {
                if (_selectedPickup != null)
                  Marker(
                    markerId: MarkerId('pickup'),
                    position: _selectedPickup!,
                    infoWindow: InfoWindow(title: 'Pickup Location'),
                  ),
                if (_showBusMarker && _busStartLatLng != null)
                  Marker(
                    markerId: MarkerId('bus_start'),
                    position: _busStartLatLng!,
                    infoWindow: InfoWindow(title: 'Bus Start Point'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue),
                  ),
              },
              onTap: _onMapTap,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
          ),
          if (_selectedPickup != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _savePickupAndShowBus,
                child: Text('Confirm Pickup Location'),
              ),
            ),
        ],
      ),
    );
  }
}
