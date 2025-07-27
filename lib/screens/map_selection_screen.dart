import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

class MapSelectionScreen extends StatefulWidget {
  final String mode; // 'start' or 'destination'
  final Function(LatLng? latLng, String? address) onLocationSelected;

  const MapSelectionScreen({
    super.key,
    required this.mode,
    required this.onLocationSelected,
  });


  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

const kGoogleApiKey = 'AIzaSyC2n6urW_4DUphPLUDaNGAW_VN53j0RP4s';

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target:
        LatLng(0.34540783865964797, 32.54297125499706), // Kampala coordinates
    zoom: 14.0,
  );

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  LatLng? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Select ${widget.mode == 'start' ? 'Start' : 'Destination'} Location'),
        backgroundColor: const Color(0xFF576238),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: () => _confirmSelection(),
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: _initialCameraPosition,
            onTap: _handleMapTap,
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF576238),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap on the map to select ${widget.mode == 'start' ? 'start' : 'destination'} location',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedLocation != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Location:',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Latitude: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      'Longitude: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _selectedLocation = null;
                                _markers.clear();
                              });
                            },
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _confirmSelection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF576238),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleMapTap(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _markers = {
        Marker(
          markerId: MarkerId(widget.mode),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            widget.mode == 'start'
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title:
                '${widget.mode == 'start' ? 'Start' : 'Destination'} Location',
          ),
        ),
      };
    });

    // Get place details from coordinates (reverse geocoding)
    try {
      GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
      final response = await places.searchNearbyWithRadius(
        Location(lat: position.latitude, lng: position.longitude),
        100, // 100 meters radius
      );

      if (response.results.isNotEmpty) {
        final placeName = response.results.first.name ?? 'Selected Location';
        // Store the place name for confirmation
        _selectedLocation = position;
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      // Get place name if available
      String? placeName;
      if (_markers.isNotEmpty) {
        placeName = _markers.first.infoWindow.title;
      }

      widget.onLocationSelected(_selectedLocation, placeName);
      Navigator.pop(context);
    }
  }
}







