import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  GoogleMapController? _mapController;
  String pickupLocation = '';
  String dropoffLocation = '';
  LatLng? _pickupCoords;
  LatLng? _dropoffCoords;
  LatLng? _busStartLatLng;
  bool _showBusMarker = false;
  Set<Polyline> polylines = {};

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropoffController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with bus data
    pickupLocation = widget.bus['startPoint'] ?? 'Select Pickup';
    dropoffLocation = widget.bus['destination'] ?? 'Select Destination';
    _pickupController.text = pickupLocation;
    _dropoffController.text = dropoffLocation;
    
    final startLat = widget.bus['startLat'];
    final startLng = widget.bus['startLng'];
    if (startLat != null && startLng != null) {
      _pickupCoords = LatLng(startLat, startLng);
      _busStartLatLng = _pickupCoords;
    }
    _updatePolyline();
  }

  void _updatePolyline() {
    setState(() {
      polylines.clear();
      final routePoints = widget.bus['routePolyline'] as List?;
      List<LatLng> points = [];
      
      if (routePoints != null) {
        points = routePoints.map((p) => LatLng(p['lat'], p['lng'])).toList();
      } else if (_pickupCoords != null && _dropoffCoords != null) {
        points = [
          _pickupCoords!,
          // Add intermediate point for smoother route (can be enhanced with real routing API)
          LatLng(
            (_pickupCoords!.latitude + (_dropoffCoords?.latitude ?? _pickupCoords!.latitude)) / 2,
            (_pickupCoords!.longitude + (_dropoffCoords?.longitude ?? _pickupCoords!.longitude)) / 2,
          ),
          _dropoffCoords!,
        ];
      }
      
      if (points.isNotEmpty) {
        polylines.add(Polyline(
          polylineId: PolylineId('route'),
          points: points,
          color: Colors.green,
          width: 5,
        ));
      }
    });
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _pickupCoords = latLng;
      pickupLocation = 'Custom Pickup (${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)})';
      _pickupController.text = pickupLocation;
      _updatePolyline();
    });
  }

  void _savePickupAndShowBus() async {
    if (_pickupCoords == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a pickup location')),
      );
      return;
    }
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
    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'userId': user.uid,
        'busId': busId,
        'driverId': driverId,
        'pickupLocation': {
          'latitude': _pickupCoords!.latitude,
          'longitude': _pickupCoords!.longitude,
        },
        'dropoffLocation': _dropoffCoords != null
            ? {
                'latitude': _dropoffCoords!.latitude,
                'longitude': _dropoffCoords!.longitude,
              }
            : null,
        'bookingTime': FieldValue.serverTimestamp(),
        'status': 'confirmed',
      });
      setState(() {
        _showBusMarker = true;
      });
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 48),
              SizedBox(height: 12),
              Text('Booking Confirmed!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
              'Your pickup${_dropoffCoords != null ? ' and dropoff' : ''} location${_dropoffCoords != null ? 's have' : ' has'} been saved and your bus is booked. Proceed to select the number of people and seats.'),
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
                      busModel: BusModel.fromJson(bus, bus['busId'] ?? bus['id'] ?? ''),
                      pickupLocation: _pickupCoords,
                      pickupAddress: pickupLocation,
                      departureDate: null,
                      returnDate: null,
                      adultCount: 1,
                      childrenCount: 0,
                    ),
                  ),
                );
              },
              child: Text('Continue'), // Fixed: Replaced 'silver' with 'child'
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
            child: Column(
              children: [
                TextField(
                  controller: _pickupController,
                  decoration: InputDecoration(
                    labelText: 'Pick Up',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      pickupLocation = value;
                      // In a full implementation, use geocoding API to update _pickupCoords
                    });
                  },
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _dropoffController,
                  decoration: InputDecoration(
                    labelText: 'Where To',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: Icon(Icons.close),
                  ),
                  onChanged: (value) {
                    setState(() {
                      dropoffLocation = value;
                      // In a full implementation, use geocoding API to update _dropoffCoords
                      _updatePolyline();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target: _pickupCoords ?? LatLng(0, 0),
                zoom: 13,
              ),
              polylines: polylines,
              markers: {
                if (_pickupCoords != null)
                  Marker(
                    markerId: MarkerId('pickup'),
                    position: _pickupCoords!,
                    infoWindow: InfoWindow(title: pickupLocation),
                  ),
                if (_dropoffCoords != null)
                  Marker(
                    markerId: MarkerId('dropoff'),
                    position: _dropoffCoords!,
                    infoWindow: InfoWindow(title: dropoffLocation),
                  ),
                if (_showBusMarker && _busStartLatLng != null)
                  Marker(
                    markerId: MarkerId('bus_start'),
                    position: _busStartLatLng!,
                    infoWindow: InfoWindow(title: 'Bus Start Point'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  ),
              },
              onTap: _onMapTap,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
          ),
          if (_pickupCoords != null)
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
