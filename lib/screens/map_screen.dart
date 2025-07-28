import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _currentLocation = const LatLng(0.0, 0.0);
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _trackUserLocation();
  }

  Future<void> _trackUserLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      LatLng updatedLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLocation = updatedLatLng;

        // Update marker for current location
        _markers.removeWhere(
          (m) => m.markerId == const MarkerId('current_location'),
        );

        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: updatedLatLng,
            infoWindow: const InfoWindow(title: 'You are here'),
            icon: MarkerIcons.userMarker,
          ),
        );
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: updatedLatLng, zoom: 16),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentLocation,
          zoom: 16,
        ),
            myLocationEnabled:
                false, // Disable default blue dot because we're showing custom marker
        myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
        markers: _markers,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
          ),
          // Zoom controls
          MapZoomControls(mapController: _mapController),
        ],
      ),
    );
  }
}





