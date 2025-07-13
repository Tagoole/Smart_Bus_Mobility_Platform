import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';

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
  bool _isLoadingAddress = false;

  void _onMapTap(LatLng position) async {
    setState(() {
      _pickedLocation = position;
      _pickedAddress = null;
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        // Build a more comprehensive address
        final addressParts = <String>[];

        // Add name if available and meaningful
        if (placemark.name != null &&
            placemark.name!.isNotEmpty &&
            placemark.name != placemark.street) {
          addressParts.add(placemark.name!);
        }

        // Add street
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          addressParts.add(placemark.street!);
        }

        // Add sublocality (neighborhood)
        if (placemark.subLocality != null &&
            placemark.subLocality!.isNotEmpty) {
          addressParts.add(placemark.subLocality!);
        }

        // Add locality (city)
        if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          addressParts.add(placemark.locality!);
        }

        // Add administrative area (state/province)
        if (placemark.administrativeArea != null &&
            placemark.administrativeArea!.isNotEmpty) {
          addressParts.add(placemark.administrativeArea!);
        }

        // Add country
        if (placemark.country != null && placemark.country!.isNotEmpty) {
          addressParts.add(placemark.country!);
        }

        // Create the final address
        String address;
        if (addressParts.isNotEmpty) {
          address = addressParts.join(', ');
        } else {
          // Fallback: use coordinates if no meaningful address found
          address =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        }

        setState(() {
          _pickedAddress = address;
          _isLoadingAddress = false;
        });
      } else {
        // No placemarks found, use coordinates
        setState(() {
          _pickedAddress =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      // Fallback to coordinates on error
      setState(() {
        _pickedAddress =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        _isLoadingAddress = false;
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
          if (_pickedAddress != null || _isLoadingAddress)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: widget.markerColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _isLoadingAddress
                        ? Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.markerColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Getting address...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          )
                        : Text(
                            _pickedAddress!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ],
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
                            infoWindow: InfoWindow(
                              title: 'Selected Location',
                              snippet: _pickedAddress ?? 'Loading address...',
                            ),
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
              onPressed:
                  _pickedLocation != null &&
                      _pickedAddress != null &&
                      !_isLoadingAddress
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
