import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utility class for safely managing Google Map controllers
/// This helps prevent crashes related to ImageReader and PlatformView issues
class MapControllerUtils {
  /// Safely disposes a map controller with error handling
  static void safeDispose(GoogleMapController? controller) {
    if (controller == null) return;

    try {
      controller.dispose();
    } catch (e) {
      print('Error disposing map controller: $e');
      // Don't re-throw to prevent crashes
    }
  }

  /// Safely disposes a completer-based map controller
  static void safeDisposeCompleter(
    Completer<GoogleMapController> controller,
  ) {
    if (!controller.isCompleted) return;

    try {
      controller.future.then((mapController) {
        mapController.dispose();
      }).catchError((e) {
        print('Error disposing completer map controller: $e');
      });
    } catch (e) {
      print('Error disposing completer map controller: $e');
      // Don't re-throw to prevent crashes
    }
  }

  /// Creates a map controller with error handling
  static void safeMapCreated(
    GoogleMapController controller,
    Completer<GoogleMapController> completer,
    GoogleMapController? mapControllerRef,
  ) {
    try {
      if (!completer.isCompleted) {
        completer.complete(controller);
      }
      mapControllerRef = controller;
    } catch (e) {
      print('Error in map created callback: $e');
    }
  }
}










