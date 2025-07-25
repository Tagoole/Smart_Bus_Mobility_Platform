import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/screens/booked_buses_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/selectseat_screen.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';

const kGoogleApiKey = 'AIzaSyC2n6urW_4DUphPLUDaNGAW_VN53j0RP4s';

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
          LatLng(
            (_pickupCoords!.latitude +
                    (_dropoffCoords?.latitude ?? _pickupCoords!.latitude)) /
                2,
            (_pickupCoords!.longitude +
                    (_dropoffCoords?.longitude ?? _pickupCoords!.longitude)) /
                2,
          ),
          _dropoffCoords!,
        ];
      }

      // Draw the main bus route polyline (green)
      if (points.isNotEmpty) {
        polylines.add(Polyline(
          polylineId: PolylineId('route'),
          points: points,
          color: Colors.green,
          width: 5,
        ));
      }

      // Draw blue polyline from pickup to nearest point on route
      if (_pickupCoords != null && points.isNotEmpty) {
        final nearest = _findNearestPointOnRoute(_pickupCoords!, points);
        if (nearest != null) {
          polylines.add(Polyline(
            polylineId: PolylineId('pickup_to_route'),
            points: [_pickupCoords!, nearest],
            color: Colors.blue,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ));
        }
      }
    });
  }

  void _onMapTap(LatLng latLng) {
    setState(() {
      _pickupCoords = latLng;
      pickupLocation =
          'Custom Pickup (${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)})';
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
    // Removed Firestore booking creation here. Only navigate to seat selection.
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
            Text('Pickup Saved!',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
            'Your pickup${_dropoffCoords != null ? ' and dropoff' : ''} location${_dropoffCoords != null ? 's have' : ' has'} been saved. Proceed to select the number of people and seats.'),
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
                    busModel:
                        BusModel.fromJson(bus, bus['busId'] ?? bus['id'] ?? ''),
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
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  LatLng? _findNearestPointOnRoute(LatLng pickup, List<LatLng> route) {
    if (route.isEmpty) return null;
    double minDist = double.infinity;
    LatLng? nearest;
    for (final point in route) {
      final dist = (pickup.latitude - point.latitude) *
              (pickup.latitude - point.latitude) +
          (pickup.longitude - point.longitude) *
              (pickup.longitude - point.longitude);
      if (dist < minDist) {
        minDist = dist;
        nearest = point;
      }
    }
    return nearest;
  }

  Future<void> _geocodePickupAndUpdate(String address) async {
    // TODO: Replace with your geocoding logic
    // For now, just simulate a LatLng (e.g., Kampala)
    LatLng simulated = LatLng(0.3476, 32.5825);
    setState(() {
      _pickupCoords = simulated;
      pickupLocation = address;
      _pickupController.text = address;
      _updatePolyline();
    });
  }

  Future<void> _setPickupFromPrediction(Prediction p) async {
    GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
    PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);
    final lat = detail.result.geometry!.location.lat;
    final lng = detail.result.geometry!.location.lng;
    setState(() {
      _pickupCoords = LatLng(lat, lng);
      pickupLocation = detail.result.name;
      _pickupController.text = detail.result.name;
      _updatePolyline();
    });
    // Optionally move the map camera
    _mapController
        ?.animateCamera(CameraUpdate.newLatLngZoom(_pickupCoords!, 15));
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
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Pick Up',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: Icon(Icons.search),
                  ),
                  onTap: () async {
                    Prediction? p = await PlacesAutocomplete.show(
                      context: context,
                      apiKey: kGoogleApiKey,
                      mode: Mode.overlay,
                      language: "en",
                      components: [Component(Component.country, "ug")],
                    );
                    if (p != null) {
                      _setPickupFromPrediction(p);
                    }
                  },
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _dropoffController,
                  decoration: InputDecoration(
                    labelText: 'Where To',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue),
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

