import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapZoomControls extends StatelessWidget {
  final GoogleMapController? mapController;
  final double? currentZoom;

  const MapZoomControls({
    super.key,
    required this.mapController,
    this.currentZoom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 100, // Position below any top UI elements
      child: Column(
        children: [
          // Zoom In Button
          Container(
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  if (mapController != null) {
                    final currentZoom = await mapController!.getZoomLevel();
                    await mapController!.animateCamera(
                      CameraUpdate.zoomTo(currentZoom + 1),
                    );
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF576238),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Zoom Out Button
          Container(
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  if (mapController != null) {
                    final currentZoom = await mapController!.getZoomLevel();
                    await mapController!.animateCamera(
                      CameraUpdate.zoomTo(currentZoom - 1),
                    );
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Color(0xFF576238),
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



