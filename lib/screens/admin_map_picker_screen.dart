import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';

class AdminMapPickerScreen extends StatefulWidget {
  final String instructions;
  final BitmapDescriptor markerIcon;
  final Color markerColor;

  const AdminMapPickerScreen({
    super.key,
    required this.instructions,
    required this.markerIcon,
    required this.markerColor,
  });

  @override
  State<AdminMapPickerScreen> createState() => _AdminMapPickerScreenState();
}

class _AdminMapPickerScreenState extends State<AdminMapPickerScreen> {
  LatLng? _pickedLocation;
  String? _pickedAddress;
  GoogleMapController? _mapController;

  void _onMapTap(LatLng position) async {
    setState(() {
      _pickedLocation = position;
      _pickedAddress = null;
    });
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final name = placemark.name ?? '';
        final street = placemark.street ?? '';
        final locality = placemark.locality ?? '';
        final country = placemark.country ?? '';
        final address = [
          name,
          street,
          locality,
          country,
        ].where((p) => p.isNotEmpty).join(', ');
        setState(() {
          _pickedAddress = address.isNotEmpty ? address : 'Selected Location';
        });
      } else {
        setState(() {
          _pickedAddress = 'Selected Location';
        });
      }
    } catch (e) {
      setState(() {
        _pickedAddress = 'Selected Location';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.instructions),
        backgroundColor: widget.markerColor,
      ),
      body: Column(
        children: [
          if (_pickedAddress != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _pickedAddress!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(0.34540783865964797, 32.54297125499706),
                    zoom: 13,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  markers: _pickedLocation == null
                      ? {}
                      : {
                          Marker(
                            markerId: const MarkerId('picked'),
                            position: _pickedLocation!,
                            icon: widget.markerIcon,
                          ),
                        },
                  onTap: _onMapTap,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                ),
                // Zoom controls
                MapZoomControls(mapController: _mapController),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: _pickedLocation != null && _pickedAddress != null
                  ? () => Navigator.pop(context, {
                      'location': _pickedLocation,
                      'address': _pickedAddress,
                    })
                  : null,
              icon: const Icon(Icons.check),
              label: const Text('Confirm Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.markerColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
