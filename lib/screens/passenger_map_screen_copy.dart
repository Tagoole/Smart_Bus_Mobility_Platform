import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;
  static final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0.34540783865964797, 32.54297125499706),
    zoom: 14,
  );


  final Set<Marker> myPolylinemarker = {};
  final Set<Polyline> _myPolyline = {};
  List<LatLng> myPolylinePoints = [
    LatLng(0.3417239507478277, 32.55091817503237),
    LatLng(0.32812375520940196, 32.55479778415132),
    // ...
  ];

  final List<Marker> myMarker = [];
  final List<Marker> markerList = [
    Marker(
      markerId: MarkerId('First'),
      position: LatLng(0.34540783865964797, 32.54297125499706),
      infoWindow: InfoWindow(title: 'My Position'),
    ),
    // ...
  ];

  List<String> images = ['images/passenger_icon.png', 'images/bus_icon.png'];
  final List<LatLng> latlngForImages = <LatLng>[
    LatLng(0.33064521748842635, 32.570565769870754),
    // ...
  ];

  packData() async {
    for (int a = 0; a < images.length; a++) {
      final icon = await MarkerIconUtils.getFixedSizeMarkerIcon(images[a]);
      myMarker.add(
        Marker(
          markerId: MarkerId(a.toString()),
          position: latlngForImages[a],
          icon: icon,
          infoWindow: InfoWindow(title: 'Title Marker$a'),
          anchor: Offset(0.5, 0.5),
        ),
      );

      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();

    for (int a = 0; a < myPolylinePoints.length; a++) {
      myPolylinemarker.add(
        Marker(
          markerId: MarkerId(a.toString()),
          position: myPolylinePoints[a],
          infoWindow: InfoWindow(
            title: "Adventure $a",
            snippet: 'I am a Star..',
          ),
          icon: BitmapDescriptor.defaultMarker,
        ),
      );
      setState(() {});
      _myPolyline.add(
        Polyline(
          polylineId: PolylineId('First'),
          points: myPolylinePoints,
          color: Colors.cyanAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: _initialPosition,
              mapType: MapType.normal,
              markers: myPolylinemarker,
              polylines: _myPolyline,
              zoomControlsEnabled: false,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
                _mapController = controller;
              },
            ),
            // Zoom controls
            MapZoomControls(mapController: _mapController),
          ],
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
          setState(() {});
        },
        child: Icon(Icons.location_searching),
      ),
    );
  }
}
