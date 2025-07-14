import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BusRoutePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> bus;
  const BusRoutePreviewScreen({Key? key, required this.bus}) : super(key: key);

  @override
  State<BusRoutePreviewScreen> createState() => _BusRoutePreviewScreenState();
}

class _BusRoutePreviewScreenState extends State<BusRoutePreviewScreen> {
  LatLng? _selectedPickup;
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;

  List<LatLng> get polylinePoints {
    final poly = widget.bus['routePolyline'] as List?;
    if (poly == null) return [];
    return poly.map((p) => LatLng(p['lat'], p['lng'])).toList();
  }

  List<LatLng> get polygonPoints {
    final poly = widget.bus['serviceAreaPolygon'] as List?;
    if (poly == null) return [];
    return poly.map((p) => LatLng(p['lat'], p['lng'])).toList();
  }

  bool isWithinPolygon(LatLng point) {
    final polygon = polygonPoints;
    if (polygon.length < 3) return false;
    int i, j = polygon.length - 1;
    bool oddNodes = false;
    for (i = 0; i < polygon.length; i++) {
      if ((polygon[i].longitude < point.longitude && polygon[j].longitude >= point.longitude ||
          polygon[j].longitude < point.longitude && polygon[i].longitude >= point.longitude) &&
          (polygon[i].latitude <= point.latitude || polygon[j].latitude <= point.latitude)) {
        if (polygon[i].latitude + (point.longitude - polygon[i].longitude) /
                (polygon[j].longitude - polygon[i].longitude) *
                (polygon[j].latitude - polygon[i].latitude) <
            point.latitude) {
          oddNodes = !oddNodes;
        }
      }
      j = i;
    }
    return oddNodes;
  }

  void _onMapTap(LatLng latLng) {
    if (polygonPoints.isNotEmpty && !isWithinPolygon(latLng)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pickup must be within the service area polygon.')),
      );
      return;
    }
    setState(() {
      _selectedPickup = latLng;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview Route & Select Pickup'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for a pickup location...',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (value) async {
                // Optionally implement search using geocoding APIs
                // For now, just show a snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Search not implemented in preview.')),
                );
              },
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: CameraPosition(
                target: polylinePoints.isNotEmpty ? polylinePoints[0] : LatLng(0, 0),
                zoom: 13,
              ),
              polylines: {
                if (polylinePoints.isNotEmpty)
                  Polyline(
                    polylineId: PolylineId('route'),
                    color: Colors.green,
                    width: 5,
                    points: polylinePoints,
                  ),
              },
              polygons: {
                if (polygonPoints.isNotEmpty)
                  Polygon(
                    polygonId: PolygonId('service_area'),
                    points: polygonPoints,
                    fillColor: Colors.blue.withOpacity(0.2),
                    strokeColor: Colors.blue,
                    strokeWidth: 2,
                  ),
              },
              markers: {
                if (_selectedPickup != null)
                  Marker(
                    markerId: MarkerId('pickup'),
                    position: _selectedPickup!,
                    infoWindow: InfoWindow(title: 'Pickup Location'),
                  ),
              },
              onTap: _onMapTap,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
          ),
          if (_selectedPickup != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _selectedPickup);
                },
                child: Text('Confirm Pickup Location'),
              ),
            ),
        ],
      ),
    );
  }
} 