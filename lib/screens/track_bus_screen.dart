import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrackBusScreen extends StatefulWidget {
  const TrackBusScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _TrackBusScreenState createState() => _TrackBusScreenState();
}

class _TrackBusScreenState extends State<TrackBusScreen> {
  // Example coordinates; replace with real-time data in production
  LatLng busLocation = LatLng(0.3476, 32.5825); // Example: Kampala
  LatLng passengerLocation = LatLng(0.3200, 32.5700); // Example: Passenger

  // Example polyline route (bus -> passenger)
  List<LatLng> routePolyline = [
    LatLng(0.3476, 32.5825),
    LatLng(0.3400, 32.5800),
    LatLng(0.3300, 32.5750),
    LatLng(0.3200, 32.5700),
  ];

  double distance = 4.2; // Example distance in km

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Track Your Bus')),
      body: Column(
        children: [
          ListTile(
            leading: Icon(Icons.directions_bus),
            title: Text('Your Booked Bus'),
            subtitle: Text('Tap for route details'),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: busLocation,
                zoom: 13,
              ),
              markers: {
                Marker(
                  markerId: MarkerId('bus'),
                  position: busLocation,
                  infoWindow: InfoWindow(title: 'Bus Location'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                ),
                Marker(
                  markerId: MarkerId('passenger'),
                  position: passengerLocation,
                  infoWindow: InfoWindow(title: 'Your Location'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                ),
              },
              polylines: {
                Polyline(
                  polylineId: PolylineId('route'),
                  points: routePolyline,
                  color: Colors.blue,
                  width: 5,
                ),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Route:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Bus is moving from its current location to your location.'),
                SizedBox(height: 8),
                Text('Distance: $distance km'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}