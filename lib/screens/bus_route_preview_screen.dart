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
  final BusModel bus;
  const BusRoutePreviewScreen({super.key, required this.bus});

  @override
  State<BusRoutePreviewScreen> createState() => _BusRoutePreviewScreenState();
}

class _BusRoutePreviewScreenState extends State<BusRoutePreviewScreen> {
  GoogleMapController? _mapController;
  String pickupLocation = '';
  LatLng? _pickupCoords;
  LatLng? _busStartLatLng;
  bool _showBusMarker = false;
  Set<Polyline> polylines = {};

  final TextEditingController _pickupController = TextEditingController();

  // --- Begin: Copied logic from PassengerMapScreen ---
  Future<void> _handlePickupSelection() async {
    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      mode: Mode.overlay,
      language: 'en',
      strictbounds: false,
      types: [""],
      decoration: const InputDecoration(
        hintText: 'Type or select pickup location',
        border: InputBorder.none,
      ),
      components: [Component(Component.country, "ug")],
    );
    if (p != null) {
      await _setPickupLocation(p);
    }
  }

  Future<void> _setPickupLocation(Prediction p) async {
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
    if (_mapController != null && _pickupCoords != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_pickupCoords!, 15.0),
      );
    }
  }

  void _clearPickup() {
    setState(() {
      _pickupCoords = null;
      _pickupController.clear();
      pickupLocation = '';
      _updatePolyline();
    });
  }
  // --- End: Copied logic from PassengerMapScreen ---

  @override
  void initState() {
    super.initState();
    // Initialize with bus data
    pickupLocation = widget.bus.startPoint;
    _pickupController.text = pickupLocation;
    final startLat = widget.bus.startLat;
    final startLng = widget.bus.startLng;
    if (startLat != null && startLng != null) {
      _pickupCoords = LatLng(startLat, startLng);
      _busStartLatLng = _pickupCoords;
    }
    _updatePolyline();
  }

  void _updatePolyline() {
    setState(() {
      polylines.clear();
      List<LatLng> points = widget.bus.getRoutePolylinePoints();
      if (points.isEmpty && _pickupCoords != null) {
        points = [
          _pickupCoords!,
        ];
      }

      // Draw the main bus route polyline (green)
      if (points.isNotEmpty) {
        polylines.add(Polyline(
          polylineId: const PolylineId('route'),
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
            polylineId: const PolylineId('pickup_to_route'),
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
        const SnackBar(content: Text('Please select a pickup location')),
      );
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to book a bus')),
      );
      return;
    }
    final bus = widget.bus;
    setState(() {
      _showBusMarker = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            SizedBox(height: 12),
            Text('Pickup Saved!',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            'Your pickup location has been saved. Proceed to select the number of people and seats.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close preview screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SelectSeatScreen(
                    origin: bus.startPoint,
                    destination: bus.destination,
                    busProvider: bus.vehicleModel,
                    plateNumber: bus.numberPlate,
                    busModel: bus,
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
            child: const Text('Continue'),
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
    LatLng simulated = const LatLng(0.3476, 32.5825);
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
        title: const Text('Preview Route & Select Pickup'),
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
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _handlePickupSelection,
                        ),
                        if (_pickupController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearPickup,
                          ),
                      ],
                    ),
                  ),
                  onTap: _handlePickupSelection,
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target: _pickupCoords ?? const LatLng(0, 0),
                zoom: 13,
              ),
              polylines: polylines,
              markers: {
                if (_pickupCoords != null)
                  Marker(
                    markerId: const MarkerId('pickup'),
                    position: _pickupCoords!,
                    infoWindow: InfoWindow(title: pickupLocation),
                  ),
                if (_showBusMarker && _busStartLatLng != null)
                  Marker(
                    markerId: const MarkerId('bus_start'),
                    position: _busStartLatLng!,
                    infoWindow: const InfoWindow(title: 'Bus Start Point'),
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
                child: const Text('Confirm Pickup Location'),
              ),
            ),
        ],
      ),
    );
  }
}


