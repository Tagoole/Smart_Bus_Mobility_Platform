import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  static CameraPosition _initialPosition = CameraPosition(
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

  Future<Uint8List> getImagesFromMarkers(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetHeight: width,
    );
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return (await frameInfo.image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  }

  packData() async {
    for (int a = 0; a < images.length; a++) {
      final Uint8List iconMaker = await getImagesFromMarkers(images[a], 40);
      myMarker.add(
        Marker(
          markerId: MarkerId(a.toString()),
          position: latlngForImages[a],
          icon: BitmapDescriptor.bytes(iconMaker),
          infoWindow: InfoWindow(title: 'Title Marker${a}'),
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
            title: "Adventure ${a}",
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
        child: GoogleMap(
          initialCameraPosition: _initialPosition,
          mapType: MapType.normal,
          markers: myPolylinemarker,
          polylines: _myPolyline,
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
          setState(() {});
        },
        child: Icon(Icons.location_searching),
      ),
    );
  }
}

