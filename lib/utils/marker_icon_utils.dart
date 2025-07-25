import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utility class for loading fixed-size marker icons
/// This ensures all markers have consistent size regardless of zoom level
class MarkerIconUtils {
  /// Fixed size for all marker icons (48x48 pixels)
  static const int markerSize = 30;

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
      ))!
          .buffer
          .asUint8List();

      return BitmapDescriptor.bytes(bytes);
    } catch (e) {
      print('-----------------------------------------');
      print('Failed to load marker icon: '
          'assetPath=$assetPath, error=$e');
      print('-----------------------------------------');
      // Fallback to default marker
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  /// Loads a marker icon from assets with a text label above the icon
  static Future<BitmapDescriptor> getLabeledMarkerIcon(
    String assetPath,
    String label, {
    int size = markerSize,
    double fontSize = 16,
  }) async {
    try {
      // Load the image
      ByteData data = await rootBundle.load(assetPath);
      ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetHeight: size,
        targetWidth: size,
      );
      ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image iconImage = frameInfo.image;

      // Calculate total image size (add space for label)
      final double labelHeight = fontSize + 8;
      final double totalHeight = size + labelHeight;

      // Create a canvas to draw label + icon
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      // Draw white background (optional, for better contrast)
      // canvas.drawRect(
      //   Rect.fromLTWH(0, 0, size.toDouble(), totalHeight),
      //   Paint()..color = const Color(0x00FFFFFF),
      // );

      // Draw label text
      final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          maxLines: 1,
        ),
      )
        ..pushStyle(ui.TextStyle(
          color: const ui.Color(0xFF222222),
          fontWeight: ui.FontWeight.bold,
        ))
        ..addText(label);
      final ui.Paragraph paragraph = pb.build();
      paragraph.layout(ui.ParagraphConstraints(width: size.toDouble()));
      canvas.drawParagraph(paragraph, ui.Offset(0, 0));

      // Draw the icon image below the label
      final double iconTop = labelHeight;
      final ui.Rect dstRect =
          ui.Rect.fromLTWH(0, iconTop, size.toDouble(), size.toDouble());
      canvas.drawImageRect(
        iconImage,
        ui.Rect.fromLTWH(
            0, 0, iconImage.width.toDouble(), iconImage.height.toDouble()),
        dstRect,
        ui.Paint(),
      );

      // End drawing and convert to image
      final ui.Image finalImage =
          await recorder.endRecording().toImage(size, (totalHeight).toInt());
      final ByteData? bytes =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
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
      await MarkerIconUtils.getFixedSizeMarkerIcon(
          'assets/images/bus_icon.png');

  /// Passenger icon for pickup locations
  static Future<BitmapDescriptor> get passengerIcon async =>
      await MarkerIconUtils.getFixedSizeMarkerIcon(
          'assets/images/passenger_icon.png');

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




