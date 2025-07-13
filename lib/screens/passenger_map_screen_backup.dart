/*import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/location_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:smart_bus_mobility_platform1/screens/booking_screen.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:intl/intl.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_model.dart';
import 'package:smart_bus_mobility_platform1/widgets/map_zoom_controls.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:smart_bus_mobility_platform1/utils/auto_refresh_service.dart';

// return user info so tha checking role is ok

class PassengerMapScreen extends StatefulWidget {
  final bool isPickupSelection;
  final BusModel? selectedBus; // Add selected bus parameter

  const PassengerMapScreen({
    super.key,
    this.isPickupSelection = false,
    this.selectedBus, // Add this parameter
  });

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

/*
tarnsfer the latlng screen to an address

*/
class _PassengerMapScreenState extends State<PassengerMapScreen>
    with AutoRefreshMixin {
  final Completer<GoogleMapController> _controller = Completer();
  GoogleMapController? _mapController;
  static final CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0.34540783865964797, 32.54297125499706),
    zoom: 14,
  );

  // Variables for pickup location functionality
  LatLng? _userLocation;
  LatLng? _pickupLocation;
  BitmapDescriptor? _pickupMarkerIcon;
  BitmapDescriptor? _busMarkerIcon;
  bool _isLoadingLocation = false;
  final Set<Marker> _allMarkers = {};

  // Bus tracking variables
  BusModel? _bookedBus;
  LatLng? _busLocation;
  String _estimatedArrival = 'Calculating...';
  bool _hasActiveBooking = false;
  Timer? _busTrackingTimer;
  Directions? _routeInfo;
  Directions? _originalRouteInfo; // Original route from start to destination
  bool _isLoadingRoute = false;

  // Booking information for multiple pickup icons
  int _adultCount = 1;
  int _childrenCount = 0;

  // Automatic refresh mechanisms
  Timer? _dataRefreshTimer;
  Timer? _routeRefreshTimer;
  StreamSubscription<QuerySnapshot>? _bookingSubscription;
  StreamSubscription<DocumentSnapshot>? _busSubscription;

  // Load custom marker icons
  Future<void> _loadMarkerIcons() async {
    try {
      // Load pickup marker icon - fixed size
      _pickupMarkerIcon = await MarkerIcons.passengerIcon;

      // Load bus marker icon - fixed size
      _busMarkerIcon = await MarkerIcons.busIcon;
    } catch (e) {
      print('Error loading marker icons: $e');
      _pickupMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
      _busMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueBlue,
      );
    }
  }

  // Check for active booking and load bus data
  Future<void> _checkActiveBooking() async {
    try {
      // If we have a selected bus from booking screen, use it for pickup selection
      if (widget.isPickupSelection && widget.selectedBus != null) {
        setState(() {
          _bookedBus = widget.selectedBus;
          _hasActiveBooking = false; // This is not an active booking yet
        });

        // Fetch original route (start to destination) for pickup selection
        await _fetchOriginalRoutePolyline();
        return;
      }

      final userId = _getCurrentUserId();
      if (userId == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'confirmed')
          .where('departureDate', isGreaterThan: DateTime.now())
          .orderBy('departureDate')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final bookingData = snapshot.docs.first.data();
        final busId = bookingData['busId'];

        if (busId != null) {
          // Get bus data
          final busDoc = await FirebaseFirestore.instance
              .collection('buses')
              .doc(busId)
              .get();

          if (busDoc.exists) {
            final busData = busDoc.data()!;
            setState(() {
              _bookedBus = BusModel.fromJson(busData, busId);
              _hasActiveBooking = true;
              // Load booking information for multiple pickup icons
              _adultCount = bookingData['adultCount'] ?? 1;
              _childrenCount = bookingData['childrenCount'] ?? 0;
            });

            // Load pickup location from booking
            if (bookingData['pickupLocation'] != null) {
              final pickup = bookingData['pickupLocation'];
              setState(() {
                _pickupLocation = LatLng(
                  pickup['latitude'],
                  pickup['longitude'],
                );
              });
            }

            // Always show route in pickup selection mode
            if (widget.isPickupSelection) {
              // Fetch original route (start to destination)
              await _fetchOriginalRoutePolyline();

              // Fetch pickup route if pickup is selected
              if (_pickupLocation != null) {
                final startLat = _bookedBus!.startLat ?? 0.0;
                final startLng = _bookedBus!.startLng ?? 0.0;
                await _fetchRoutePolyline(
                  LatLng(startLat, startLng),
                  _pickupLocation!,
                );
              }
            }

            // Start bus tracking
            _startBusTracking();
          }
        }
      }
    } catch (e) {
      print('Error checking active booking: $e');
    }
  }

  // Start bus tracking timer
  void _startBusTracking() {
    _busTrackingTimer?.cancel();
    _busTrackingTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _updateBusLocation();
    });

    // Initial update
    _updateBusLocation();
  }

  // Update bus location and calculate ETA
  Future<void> _updateBusLocation() async {
    if (_bookedBus == null || _pickupLocation == null) return;

    try {
      // Get bus's current location from Firestore
      final busDoc = await FirebaseFirestore.instance
          .collection('buses')
          .doc(_bookedBus!.busId)
          .get();

      if (busDoc.exists) {
        final busData = busDoc.data()!;

        // Check if bus has current location data
        if (busData['currentLocation'] != null) {
          final location = busData['currentLocation'];
          final newBusLocation = LatLng(
            location['latitude'],
            location['longitude'],
          );

          setState(() {
            _busLocation = newBusLocation;
          });

          // Calculate ETA and fetch route polyline
          await _calculateETAAndRoute();
          await _fetchRoutePolyline(_busLocation!, _pickupLocation!);
          _updateMarkers();
        } else {
          // If no current location, use a default location or show message
          print('Bus location not available yet');
          setState(() {
            _estimatedArrival = 'Location unavailable';
            _routeInfo = null;
          });
        }
      }
    } catch (e) {
      print('Error updating bus location: $e');
      setState(() {
        _routeInfo = null;
      });
    }
  }

  /// Fetches the route polyline from Google Directions API and updates _routeInfo
  Future<void> _fetchRoutePolyline(LatLng start, LatLng end) async {
    setState(() {
      _isLoadingRoute = true;
    });
    try {
      final directions = await DirectionsRepository().getDirections(
        origin: start,
        destination: end,
      );
      setState(() {
        _routeInfo = directions;
        _isLoadingRoute = false;
      });
    } catch (e) {
      print('Error fetching route polyline: $e');
      setState(() {
        _routeInfo = null;
        _isLoadingRoute = false;
      });
    }
  }

  /// Fetches the original route polyline (start to destination)
  Future<void> _fetchOriginalRoutePolyline() async {
    if (_bookedBus == null) return;

    try {
      final startLat = _bookedBus!.startLat ?? 0.0;
      final startLng = _bookedBus!.startLng ?? 0.0;
      final destLat = _bookedBus!.destinationLat ?? 0.0;
      final destLng = _bookedBus!.destinationLng ?? 0.0;

      final directions = await DirectionsRepository().getDirections(
        origin: LatLng(startLat, startLng),
        destination: LatLng(destLat, destLng),
      );
      setState(() {
        _originalRouteInfo = directions;
      });

      // Focus camera on the route area
      _focusCameraOnRoute();
    } catch (e) {
      print('Error fetching original route polyline: $e');
      setState(() {
        _originalRouteInfo = null;
      });
    }
  }

  // Focus camera on the route area
  void _focusCameraOnRoute() {
    if (_originalRouteInfo == null ||
        _originalRouteInfo!.polylinePoints.isEmpty)
      return;

    try {
      // Calculate bounds of the route
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;

      for (var point in _originalRouteInfo!.polylinePoints) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }

      // Add some padding around the route
      const padding = 0.01; // About 1km padding
      minLat -= padding;
      maxLat += padding;
      minLng -= padding;
      maxLng += padding;

      // Calculate center point
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      // Calculate appropriate zoom level based on route size
      final latDiff = maxLat - minLat;
      final lngDiff = maxLng - minLng;
      final maxDiff = math.max(latDiff, lngDiff);

      double zoom = 14.0; // Default zoom
      if (maxDiff > 0.1) {
        zoom = 10.0; // Very large route
      } else if (maxDiff > 0.05) {
        zoom = 11.0; // Large route
      } else if (maxDiff > 0.02) {
        zoom = 12.0; // Medium route
      } else if (maxDiff > 0.01) {
        zoom = 13.0; // Small route
      } else {
        zoom = 14.0; // Very small route
      }

      // Animate camera to focus on route area
      if (_controller.isCompleted) {
        _controller.future.then((controller) {
          controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: LatLng(centerLat, centerLng), zoom: zoom),
            ),
          );
        });
      }
    } catch (e) {
      print('Error focusing camera on route: $e');
    }
  }

  // Calculate ETA and route using Google Directions API
  Future<void> _calculateETAAndRoute() async {
    if (_busLocation == null || _pickupLocation == null) return;

    try {
      // For demo purposes, we'll use a simple calculation
      // In production, you would use Google Directions API
      final distance = _calculateDistance(_busLocation!, _pickupLocation!);
      final estimatedMinutes = (distance / 1000 * 2)
          .round(); // Assuming 30 km/h average speed

      setState(() {
        _estimatedArrival = '$estimatedMinutes min';
      });

      // Generate route polyline (simplified for demo)
      // await _generateRoutePolyline(); // This line is removed
    } catch (e) {
      print('Error calculating ETA: $e');
      setState(() {
        _estimatedArrival = 'Unable to calculate';
      });
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // meters
    final double lat1 = start.latitude * math.pi / 180;
    final double lat2 = end.latitude * math.pi / 180;
    final double deltaLat = (end.latitude - start.latitude) * math.pi / 180;
    final double deltaLon = (end.longitude - start.longitude) * math.pi / 180;

    final double a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Get user's current location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(
          'Location services are disabled. Please enable location services.',
        );
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('Location permissions are denied.');
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('Location permissions are permanently denied.');
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      // Try to get last known position first (only on mobile platforms)
      if (!kIsWeb) {
        try {
          Position? lastKnownPosition = await Geolocator.getLastKnownPosition();
          if (lastKnownPosition != null) {
            setState(() {
              _userLocation = LatLng(
                lastKnownPosition.latitude,
                lastKnownPosition.longitude,
              );
              _isLoadingLocation = false;
            });

            // Update camera to user location
            if (_controller.isCompleted) {
              GoogleMapController controller = await _controller.future;
              controller.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _userLocation!, zoom: 15),
                ),
              );
            }

            _updateMarkers();
            _showSnackBar('Location updated successfully!');
            return;
          }
        } catch (e) {
          print('Last known position not available: $e');
        }
      }

      // If no last known position or on web, try to get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      );

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Update camera to user location
      if (_controller.isCompleted) {
        GoogleMapController controller = await _controller.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _userLocation!, zoom: 15),
          ),
        );
      }

      _updateMarkers();
      _showSnackBar('Location updated successfully!');
    } catch (e) {
      print('Error getting location: $e');
      _showSnackBar('Error getting your location. Please try again.');
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  // Get current user ID
  String? _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // Add pickup location
  Future<void> _addPickupLocation(LatLng location) async {
    setState(() {
      _pickupLocation = location;
    });
    _updateMarkers();

    // If this is pickup selection mode, don't save to Firestore
    if (widget.isPickupSelection) {
      _showSnackBar('Pickup location selected. Tap "Confirm" to save.');
      return;
    }

    // Save pickup location to Firestore (only for regular mode)
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        _showSnackBar('User not authenticated. Please login again.');
        return;
      }

      // First, deactivate all existing pickup locations for this user
      final existingLocations = await FirebaseFirestore.instance
          .collection('pickup_locations')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .get();

      // Deactivate old locations
      for (var doc in existingLocations.docs) {
        await doc.reference.update({'isActive': false});
      }

      // Create location model
      final locationModel = LocationModel.createPickupLocation(
        userId: userId,
        latitude: location.latitude,
        longitude: location.longitude,
        locationName: 'Pickup Location',
        notes: 'Added on ${formatDate(DateTime.now())}',
      );

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('pickup_locations')
          .add(locationModel.toJson());

      print('Pickup location saved with ID: ${docRef.id}');
      _showSnackBar('Pickup location saved successfully!');
    } catch (e) {
      print('Error saving pickup location: $e');
      _showSnackBar('Error saving pickup location. Please try again.');
    }
  }

  // Update all markers on the map
  void _updateMarkers() {
    _allMarkers.clear();

    // Add user location marker
    if (_userLocation != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('user_location'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          anchor: Offset(0.5, 0.5), // Center the marker
          flat: true, // Keep marker flat (not tilted)
          infoWindow: InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    }

    // Add bus start location marker (always show when bus is available)
    if (_bookedBus != null &&
        _bookedBus!.startLat != null &&
        _bookedBus!.startLng != null) {
      _allMarkers.add(
        Marker(
          markerId: MarkerId('bus_start_location'),
          position: LatLng(_bookedBus!.startLat!, _bookedBus!.startLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          anchor: Offset(0.5, 0.5), // Center the marker
          flat: true, // Keep marker flat (not tilted)
          infoWindow: InfoWindow(
            title: 'Bus Start Location',
            snippet: _bookedBus!.startPoint.isNotEmpty
                ? _bookedBus!.startPoint
                : 'Bus starting point',
          ),
        ),
      );
    }

    // Add pickup location markers - multiple icons based on passenger count
    if (_pickupLocation != null && _pickupMarkerIcon != null) {
      final totalPassengers = _adultCount + _childrenCount;

      // Create multiple markers based on total passenger count
      for (int i = 0; i < totalPassengers; i++) {
        // Slightly offset each marker to avoid overlap
        final offset = i * 0.0001; // Small offset in degrees
        final offsetLatLng = LatLng(
          _pickupLocation!.latitude + offset,
          _pickupLocation!.longitude + offset,
        );

        _allMarkers.add(
          Marker(
            markerId: MarkerId('pickup_location_$i'),
            position: offsetLatLng,
            icon: _pickupMarkerIcon!,
            anchor: Offset(0.5, 0.5), // Center the marker
            flat: true, // Keep marker flat (not tilted)
            infoWindow: InfoWindow(
              title: 'Pickup Location (${i + 1}/$totalPassengers)',
              snippet: widget.isPickupSelection
                  ? 'Tap to remove'
                  : 'Selected pickup point',
            ),
            onTap: () => _removePickupLocation(),
          ),
        );
      }
    }

    // Add bus marker if tracking
    if (_busLocation != null && _busMarkerIcon != null && _bookedBus != null) {
      final totalPassengers = _adultCount + _childrenCount;
      _allMarkers.add(
        Marker(
          markerId: MarkerId('bus_location'),
          position: _busLocation!,
          icon: _busMarkerIcon!,
          anchor: Offset(0.5, 0.5), // Center the marker
          flat: true, // Keep marker flat (not tilted)
          infoWindow: InfoWindow(
            title: 'Your Bus',
            snippet:
                '${_bookedBus!.numberPlate} • ETA: $_estimatedArrival • $totalPassengers passengers',
          ),
        ),
      );
    }
  }

  // Remove pickup location
  void _removePickupLocation() async {
    setState(() {
      _pickupLocation = null;
    });
    _updateMarkers();

    // Deactivate pickup location in Firestore
    try {
      final userId = _getCurrentUserId();
      if (userId != null) {
        final existingLocations = await FirebaseFirestore.instance
            .collection('pickup_locations')
            .where('userId', isEqualTo: userId)
            .where('isActive', isEqualTo: true)
            .get();

        // Deactivate all active pickup locations
        for (var doc in existingLocations.docs) {
          await doc.reference.update({'isActive': false});
        }
      }
    } catch (e) {
      print('Error removing pickup location: $e');
    }

    _showSnackBar('Pickup location removed');
  }

  // Show snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Load saved pickup locations
  Future<void> _loadSavedPickupLocations() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) return;

      // Try to load the most recent active pickup location
      final snapshot = await FirebaseFirestore.instance
          .collection('pickup_locations')
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final locationData = snapshot.docs.first.data();
        final latitude = locationData['latitude'] as double;
        final longitude = locationData['longitude'] as double;
        setState(() {
          _pickupLocation = LatLng(latitude, longitude);
        });
        _updateMarkers();
        print('Loaded saved pickup location from pickup_locations');
        // Always show route in pickup selection mode
        if (widget.isPickupSelection && _bookedBus != null) {
          // Fetch original route (start to destination)
          await _fetchOriginalRoutePolyline();

          // Fetch pickup route
          final startLat = _bookedBus!.startLat ?? 0.0;
          final startLng = _bookedBus!.startLng ?? 0.0;
          await _fetchRoutePolyline(
            LatLng(startLat, startLng),
            LatLng(latitude, longitude),
          );
        }
      } else {
        // Fallback: Try to load from the latest booking
        final bookingSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'confirmed')
            .orderBy('departureDate', descending: true)
            .limit(1)
            .get();
        if (bookingSnapshot.docs.isNotEmpty) {
          final bookingData = bookingSnapshot.docs.first.data();
          if (bookingData['pickupLocation'] != null) {
            final pickup = bookingData['pickupLocation'];
            setState(() {
              _pickupLocation = LatLng(pickup['latitude'], pickup['longitude']);
            });
            _updateMarkers();
            print('Loaded pickup location from latest booking');
            // Always show route in pickup selection mode
            if (widget.isPickupSelection && _bookedBus != null) {
              // Fetch original route (start to destination)
              await _fetchOriginalRoutePolyline();

              // Fetch pickup route
              final startLat = _bookedBus!.startLat ?? 0.0;
              final startLng = _bookedBus!.startLng ?? 0.0;
              await _fetchRoutePolyline(
                LatLng(startLat, startLng),
                LatLng(pickup['latitude'], pickup['longitude']),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error loading saved pickup locations: $e');
    }
  }

  // Navigate to booking screen
  void _navigateToBooking() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => FindBusScreen()),
    );
  }

  // Confirm pickup location and return to booking screen
  void _confirmPickupLocation() async {
    if (_pickupLocation == null) {
      _showSnackBar('Please select a pickup location first');
      return;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
      );

      String address;
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
        if (addressParts.isNotEmpty) {
          address = addressParts.join(', ');
        } else {
          // Fallback: use coordinates if no meaningful address found
          address =
              '${_pickupLocation!.latitude.toStringAsFixed(6)}, ${_pickupLocation!.longitude.toStringAsFixed(6)}';
        }
      } else {
        // No placemarks found, use coordinates
        address =
            '${_pickupLocation!.latitude.toStringAsFixed(6)}, ${_pickupLocation!.longitude.toStringAsFixed(6)}';
      }

      Navigator.pop(context, {'location': _pickupLocation, 'address': address});
    } catch (e) {
      print('Error getting address: $e');
      // Fallback to coordinates on error
      Navigator.pop(context, {
        'location': _pickupLocation,
        'address':
            '${_pickupLocation!.latitude.toStringAsFixed(6)}, ${_pickupLocation!.longitude.toStringAsFixed(6)}',
      });
    }
  }

  String formatDate(DateTime date) {
    final daySuffix = _getDayOfMonthSuffix(date.day);
    final formatted =
        DateFormat('EEEE d').format(date) +
        daySuffix +
        DateFormat(' MMMM, yyyy').format(date);
    return formatted;
  }

  String _getDayOfMonthSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _getCurrentLocation();
    _checkActiveBooking();
    _loadSavedPickupLocations();

    // Set up automatic refresh mechanisms
    _setupAutomaticRefresh();

    // If in pickup selection mode and bus is known, show route from start to destination
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.isPickupSelection && _bookedBus != null) {
        // Fetch original route (start to destination)
        await _fetchOriginalRoutePolyline();

        // Fetch pickup route if pickup is selected
        if (_pickupLocation != null) {
          final startLat = _bookedBus!.startLat ?? 0.0;
          final startLng = _bookedBus!.startLng ?? 0.0;
          await _fetchRoutePolyline(
            LatLng(startLat, startLng),
            _pickupLocation!,
          );
        }
      }
    });
  }

  // Set up automatic refresh mechanisms
  void _setupAutomaticRefresh() {
    // Refresh all data every 2 minutes
    Timer.periodic(Duration(minutes: 2), (timer) {
      if (mounted) {
        _refreshScreenData();
      }
    });

    // Refresh routes every 5 minutes
    Timer.periodic(Duration(minutes: 5), (timer) {
      if (mounted) {
        _refreshRoutes();
      }
    });

    // Set up real-time booking monitoring
    _setupBookingMonitoring();
  }

  // Set up real-time booking monitoring
  void _setupBookingMonitoring() {
    final userId = _getCurrentUserId();
    if (userId != null) {
      // Monitor active bookings in real-time
      _bookingSubscription = FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'confirmed')
          .snapshots()
          .listen((snapshot) {
            if (mounted) {
              _handleBookingUpdates(snapshot);
            }
          });
    }
  }

  // Handle booking updates from real-time stream
  void _handleBookingUpdates(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      final bookingData = snapshot.docs.first.data() as Map<String, dynamic>;
      final busId = bookingData['busId'];

      if (busId != null && _bookedBus?.busId != busId) {
        // Booking changed, refresh bus data
        _loadBusData(busId);
      }
    } else {
      // No active bookings
      setState(() {
        _hasActiveBooking = false;
        _bookedBus = null;
      });
    }
  }

  // Load bus data and set up real-time monitoring
  Future<void> _loadBusData(String busId) async {
    try {
      // Cancel existing bus subscription
      _busSubscription?.cancel();

      // Set up real-time bus monitoring
      _busSubscription = FirebaseFirestore.instance
          .collection('buses')
          .doc(busId)
          .snapshots()
          .listen((snapshot) {
            if (mounted && snapshot.exists) {
              final busData = BusModel.fromJson(snapshot.data()!, busId);
              setState(() {
                _bookedBus = busData;
                _hasActiveBooking = true;
              });

              // Update bus location if available
              if (snapshot.data()!['currentLocation'] != null) {
                final location = snapshot.data()!['currentLocation'];
                setState(() {
                  _busLocation = LatLng(
                    location['latitude'],
                    location['longitude'],
                  );
                });
                _updateMarkers();
              }

              // Fetch routes for active booking
              if (_hasActiveBooking) {
                _fetchOriginalRoutePolyline();
                if (_pickupLocation != null) {
                  final startLat = _bookedBus!.startLat ?? 0.0;
                  final startLng = _bookedBus!.startLng ?? 0.0;
                  _fetchRoutePolyline(
                    LatLng(startLat, startLng),
                    _pickupLocation!,
                  );
                }
              }
            }
          });
    } catch (e) {
      print('Error loading bus data: $e');
    }
  }

  // Refresh routes
  Future<void> _refreshRoutes() async {
    if (_bookedBus != null) {
      await _fetchOriginalRoutePolyline();
      if (_pickupLocation != null) {
        final startLat = _bookedBus!.startLat ?? 0.0;
        final startLng = _bookedBus!.startLng ?? 0.0;
        await _fetchRoutePolyline(LatLng(startLat, startLng), _pickupLocation!);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen becomes active (e.g., when returning from seat selection)
    _refreshScreenData();
  }

  // Refresh all screen data
  Future<void> _refreshScreenData() async {
    await _checkActiveBooking();
    await _loadSavedPickupLocations();
    _updateMarkers();
  }

  @override
  void dispose() {
    // Cancel bus tracking timer
    _busTrackingTimer?.cancel();

    // Cancel automatic refresh timers
    _dataRefreshTimer?.cancel();
    _routeRefreshTimer?.cancel();

    // Cancel stream subscriptions
    _bookingSubscription?.cancel();
    _busSubscription?.cancel();

    // Dispose map controller properly
    _mapController?.dispose();

    // Clear any pending operations
    if (_controller.isCompleted) {
      _controller.future.then((controller) {
        try {
          controller.dispose();
        } catch (e) {
          print('Error disposing map controller: $e');
        }
      });
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.isPickupSelection ? 'Select Pickup Location' : 'Passenger Map',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF576238),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.isPickupSelection && _pickupLocation != null)
            TextButton(
              onPressed: _confirmPickupLocation,
              child: Text(
                'Confirm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshScreenData,
        child: Column(
          children: [
            // ETA Display at top (only show if has active booking)
            if (_hasActiveBooking && _bookedBus != null)
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _bookedBus!.numberPlate,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${_bookedBus!.startPoint} → ${_bookedBus!.destination}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _estimatedArrival,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Pickup location info card (only show if has saved pickup location and no active booking)
            if (!_hasActiveBooking &&
                _pickupLocation != null &&
                !widget.isPickupSelection)
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved Pickup Location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Text(
                            'Your previously saved pickup point',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _removePickupLocation,
                      icon: Icon(Icons.close, color: Colors.red),
                      tooltip: 'Remove pickup location',
                    ),
                  ],
                ),
              ),

            // Bus route info card (show when in pickup selection mode with selected bus)
            if (widget.isPickupSelection && _bookedBus != null)
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF576238),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.route,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Bus Route',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                _bookedBus!.numberPlate,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.route, size: 16, color: Color(0xFF6B7280)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_bookedBus!.startPoint} → ${_bookedBus!.destination}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tap on the map to select your pickup location',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Map
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      GoogleMap(
                        onMapCreated: (GoogleMapController controller) {
                          _controller.complete(controller);
                          _mapController = controller;
                        },
                        initialCameraPosition: _initialPosition,
                        markers: _allMarkers,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        // Draw the route polyline if available
                        polylines: {
                          // Original route (start to destination) - show in pickup selection and active booking
                          if (_originalRouteInfo != null &&
                              (widget.isPickupSelection || _hasActiveBooking))
                            Polyline(
                              polylineId: PolylineId('original_route'),
                              color: Colors.orange,
                              width: 4,
                              points: _originalRouteInfo!.polylinePoints
                                  .map((e) => LatLng(e.latitude, e.longitude))
                                  .toList(),
                            ),
                          // Pickup route (start to pickup) - show in pickup selection
                          if (_routeInfo != null && widget.isPickupSelection)
                            Polyline(
                              polylineId: PolylineId('pickup_route'),
                              color: Colors.orange,
                              width: 5,
                              points: _routeInfo!.polylinePoints
                                  .map((e) => LatLng(e.latitude, e.longitude))
                                  .toList(),
                            ),
                          // Bus tracking route (bus to pickup) - show in active booking
                          if (_routeInfo != null && _hasActiveBooking)
                            Polyline(
                              polylineId: PolylineId('bus_tracking_route'),
                              color: Colors.blue,
                              width: 5,
                              points: _routeInfo!.polylinePoints
                                  .map((e) => LatLng(e.latitude, e.longitude))
                                  .toList(),
                            ),
                        },
                        onTap: (LatLng latLng) async {
                          if (widget.isPickupSelection) {
                            await _addPickupLocation(latLng);
                            // Fetch original route (start to destination) if not already fetched
                            if (_originalRouteInfo == null) {
                              await _fetchOriginalRoutePolyline();
                            }
                            // Fetch route from bus start to pickup
                            if (_bookedBus != null) {
                              final startLat = _bookedBus!.startLat ?? 0.0;
                              final startLng = _bookedBus!.startLng ?? 0.0;
                              await _fetchRoutePolyline(
                                LatLng(startLat, startLng),
                                latLng,
                              );
                            }
                          }
                        },
                      ),
                      if (_isLoadingRoute)
                        const Center(child: CircularProgressIndicator()),
                      // Zoom controls
                      MapZoomControls(mapController: _mapController),
                      // Route legend (show when routes are available)
                      if ((widget.isPickupSelection || _hasActiveBooking) &&
                          (_originalRouteInfo != null || _routeInfo != null))
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Route Legend',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 8),
                                // Bus start location marker
                                if (_bookedBus != null &&
                                    _bookedBus!.startLat != null) ...[
                                  Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Bus Start',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                ],
                                if (_originalRouteInfo != null) ...[
                                  Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Bus Route',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                ],
                                if (_routeInfo != null &&
                                    widget.isPickupSelection) ...[
                                  Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Pickup Route',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (_routeInfo != null &&
                                    _hasActiveBooking) ...[
                                  Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Bus to Pickup',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      // Bottom action bar - Google Maps style circular buttons (stacked vertically on bottom right)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Column(
                          children: [
                            // My Location button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: _isLoadingLocation
                                    ? null
                                    : _getCurrentLocation,
                                icon: _isLoadingLocation
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.grey,
                                              ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.my_location,
                                        color: Colors.grey[700],
                                      ),
                                tooltip: 'My Location',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  padding: EdgeInsets.all(12),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            // Book Bus button
                            if (!widget.isPickupSelection)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: _navigateToBooking,
                                  icon: Icon(
                                    Icons.directions_bus,
                                    color: Colors.white,
                                  ),
                                  tooltip: 'Book Bus',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
*/