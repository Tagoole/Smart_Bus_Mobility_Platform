import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}


/*
tarnsfer the latlng screen to an address

*/
class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  static CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0.34540783865964797, 32.54297125499706),
    zoom: 14,
  );

  final List<Marker> myMarker = [];
  final List<Marker> markerList = [
    Marker(
      markerId: MarkerId('First'),
      position: LatLng(0.34540783865964797, 32.54297125499706),
      infoWindow: InfoWindow(title: 'My Position'),
    ),

    Marker(
      markerId: MarkerId('Second'),
      position: LatLng(0.3437341705331724, 32.56696093114697),
      infoWindow: InfoWindow(title: 'G9 Area'),
    ),
    Marker(
      markerId: MarkerId('Second'),
      position: LatLng(0.35364743126561693, 32.57339823243943),
      infoWindow: InfoWindow(title: 'G10 Area'),
    ),
  ];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    myMarker.addAll(markerList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GoogleMap(
          initialCameraPosition: _initialPosition,
          mapType: MapType.normal,
          markers: Set<Marker>.of(markerList),
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          GoogleMapController controller = await _controller.future;
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: LatLng(0.34755, 32.56606), zoom: 14),
            ),
          );
          setState(() {
            
          });
        },
        child: Icon(Icons.location_searching),
      ),
    );
  }
}
