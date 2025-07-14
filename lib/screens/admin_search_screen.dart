import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';

class AdminSearchScreen extends StatefulWidget {
  final String mode; // 'start' or 'destination'
  final Function(LatLng latLng, String address) onLocationSelected;

  const AdminSearchScreen({
    super.key,
    required this.mode,
    required this.onLocationSelected,
  });

  @override
  State<AdminSearchScreen> createState() => _AdminSearchScreenState();
}

const kGoogleApiKey = 'AIzaSyC2n6urW_4DUphPLUDaNGAW_VN53j0RP4s';
final homeScaffoldKey = GlobalKey<ScaffoldState>();

class _AdminSearchScreenState extends State<AdminSearchScreen> {
  static const CameraPosition initialCameraPosition = CameraPosition(
    target: LatLng(0.34540783865964797, 32.54297125499706), // Kampala coordinates
    zoom: 14.0,
  );

  Set<Marker> markersList = {};
  late GoogleMapController googleMapController;
  final Mode _mode = Mode.overlay;
  LatLng? selectedLocation;
  String? selectedAddress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: homeScaffoldKey,
      appBar: AppBar(
        title: Text('Select ${widget.mode == 'start' ? 'Start' : 'Destination'}'),
        backgroundColor: const Color(0xFF576238),
        foregroundColor: Colors.white,
        actions: [
          if (selectedLocation != null)
            TextButton(
              onPressed: _confirmSelection,
              child: const Text(
                'Confirm',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleSearch,
                        icon: const Icon(Icons.search, size: 20),
                        label: Text('Search ${widget.mode == 'start' ? 'Start' : 'Destination'}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.mode == 'start' 
                              ? const Color(0xFF90EE90) 
                              : const Color(0xFFFF6B6B),
                          foregroundColor: widget.mode == 'start' 
                              ? const Color(0xFF111827) 
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedAddress != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: widget.mode == 'start' 
                              ? const Color(0xFF90EE90) 
                              : const Color(0xFFFF6B6B),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Location:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: widget.mode == 'start' 
                                      ? const Color(0xFF576238) 
                                      : const Color(0xFFDC2626),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedAddress!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _clearSelection,
                          icon: const Icon(Icons.clear, size: 20),
                          color: const Color(0xFF6B7280),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Map Section
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: initialCameraPosition,
                  markers: markersList,
                  mapType: MapType.normal,
                  onMapCreated: (GoogleMapController controller) {
                    googleMapController = controller;
                  },
                  onTap: _handleMapTap,
                ),
                if (selectedLocation == null)
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
                              'Search for a location or tap on the map to select',
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSearch() async {
    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: kGoogleApiKey,
      onError: onError,
      mode: _mode,
      language: 'en',
      strictbounds: false,
      types: [""],
      decoration: InputDecoration(
        hintText: 'Search ${widget.mode == 'start' ? 'start' : 'destination'} location...',
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
      components: [Component(Component.country, "ug")],
    );

    if (p != null) {
      await displayPrediction(p, homeScaffoldKey.currentState);
    }
  }

  void onError(PlacesAutocompleteResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: 'Error',
        message: response.errorMessage!,
        contentType: ContentType.failure,
      ),
    ));
  }

  Future<void> displayPrediction(Prediction p, ScaffoldState? currentState) async {
    try {
      GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
      PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);

      final lat = detail.result.geometry!.location.lat;
      final lng = detail.result.geometry!.location.lng;
      final address = detail.result.formattedAddress ?? p.description ?? 'Selected Location';

      setState(() {
        selectedLocation = LatLng(lat, lng);
        selectedAddress = address;
        markersList.clear();
        markersList.add(Marker(
          markerId: MarkerId(widget.mode),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            widget.mode == 'start' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(title: address),
        ));
      });

      googleMapController.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.0),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error getting location details: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _handleMapTap(LatLng position) async {
    try {
      // Get place details from coordinates (reverse geocoding)
      GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: kGoogleApiKey);
      final response = await places.searchNearbyWithRadius(
        Location(lat: position.latitude, lng: position.longitude),
        100, // 100 meters radius
      );

      String address = 'Selected Location';
      if (response.results.isNotEmpty) {
        address = response.results.first.formattedAddress ?? 
                 response.results.first.name ?? 
                 'Selected Location';
      }

      setState(() {
        selectedLocation = position;
        selectedAddress = address;
        markersList.clear();
        markersList.add(Marker(
          markerId: MarkerId(widget.mode),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            widget.mode == 'start' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(title: address),
        ));
      });
    } catch (e) {
      // Fallback to coordinates if reverse geocoding fails
      setState(() {
        selectedLocation = position;
        selectedAddress = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        markersList.clear();
        markersList.add(Marker(
          markerId: MarkerId(widget.mode),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            widget.mode == 'start' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(title: selectedAddress),
        ));
      });
    }
  }

  void _clearSelection() {
    setState(() {
      selectedLocation = null;
      selectedAddress = null;
      markersList.clear();
    });
  }

  void _confirmSelection() {
    if (selectedLocation != null && selectedAddress != null) {
      widget.onLocationSelected(selectedLocation!, selectedAddress!);
      Navigator.pop(context);
    }
  }
} 