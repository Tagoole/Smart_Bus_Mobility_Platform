import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utility class for loading fixed-size marker icons
/// This ensures all markers have consistent size regardless of zoom level
class MarkerIconUtils {
  /// Fixed size for all marker icons (48x48 pixels)
  static const int markerSize = 48;

  /// Loads a marker icon from assets with fixed size
  ///
  /// [assetPath] - Path to the image asset (e.g., 'images/bus_icon.png')
  /// [size] - Size in pixels (defaults to markerSize for consistency)
  ///
  /// Returns a BitmapDescriptor that can be used for markers
  static Future<BitmapDescriptor> getFixedSizeMarkerIcon(
    String assetPath, {
    int size = markerSize,
  }) async {
    try {
      ByteData data = await rootBundle.load(assetPath);
      ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetHeight: size,
        targetWidth: size,
      );
      ui.FrameInfo frameInfo = await codec.getNextFrame();
      final Uint8List bytes = (await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();

      return BitmapDescriptor.bytes(bytes);
    } catch (e) {
      // Fallback to default marker
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }
}

/// Predefined marker icons for common use cases
class MarkerIcons {
  /// Bus icon for driver and bus markers
  static Future<BitmapDescriptor> get busIcon async =>
      await MarkerIconUtils.getFixedSizeMarkerIcon('images/bus_icon.png');

  /// Passenger icon for pickup locations
  static Future<BitmapDescriptor> get passengerIcon async =>
      await MarkerIconUtils.getFixedSizeMarkerIcon('images/passenger_icon.png');

  /// Start location marker (green)
  static BitmapDescriptor get startMarker =>
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

  /// End location marker (red)
  static BitmapDescriptor get endMarker =>
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);

  /// User location marker (blue)
  static BitmapDescriptor get userMarker =>
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);

  /// Driver location marker (azure)
  static BitmapDescriptor get driverMarker =>
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
}
