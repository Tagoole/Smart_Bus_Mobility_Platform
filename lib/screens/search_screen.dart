import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchPlacesScreen extends StatefulWidget {
  const SearchPlacesScreen({Key? key}) : super(key: key);

  @override
  State<SearchPlacesScreen> createState() => _SearchPlacesScreenState();
}

const kGoogleApiKey = 'AIzaSyC2n6urW_4DUphPLUDaNGAW_VN53j0RP4s';
final homeScaffoldKey = GlobalKey<ScaffoldState>();

class _SearchPlacesScreenState extends State<SearchPlacesScreen> {
  static const CameraPosition initialCameraPosition = CameraPosition(
      target:
          LatLng(0.34540783865964797, 32.54297125499706), // Kampala coordinates
      zoom: 14.0);

  Set<Marker> markersList = {};
  late GoogleMapController googleMapController;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: homeScaffoldKey,
      appBar: AppBar(
        title: const Text("Search Places"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialCameraPosition,
            markers: markersList,
            mapType: MapType.normal,
            onMapCreated: (GoogleMapController controller) {
              googleMapController = controller;
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search for a place...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (_) => _searchLocation(),
                      ),
                    ),
                    IconButton(
                      onPressed: _isSearching ? null : _searchLocation,
                      icon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchLocation() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final query = Uri.encodeComponent(_searchController.text.trim());
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$query&key=$kGoogleApiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          final address = result['formatted_address'];

          markersList.clear();
          markersList.add(Marker(
            markerId: const MarkerId("0"),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: result['name'] ?? 'Searched Location',
              snippet: address,
            ),
          ));

          setState(() {});

          googleMapController.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.0));

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            content: AwesomeSnackbarContent(
              title: 'Success',
              message: 'Location found: $address',
              contentType: ContentType.success,
            ),
          ));
        } else {
          _showError('Location not found. Please try a different search term.');
        }
      } else {
        _showError('Failed to search location. Please try again.');
      }
    } catch (e) {
      _showError('Error searching location: ${e.toString()}');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: 'Error',
        message: message,
        contentType: ContentType.failure,
      ),
    ));
  }
}
