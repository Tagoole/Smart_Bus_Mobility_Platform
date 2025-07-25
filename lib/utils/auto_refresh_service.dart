import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AutoRefreshService {
  static final AutoRefreshService _instance = AutoRefreshService._internal();
  factory AutoRefreshService() => _instance;
  AutoRefreshService._internal();

  // Timers for different types of refresh
  Timer? _busRefreshTimer;
  Timer? _bookingRefreshTimer;
  Timer? _locationRefreshTimer;
  Timer? _generalDataTimer;
  Timer? _etaUpdateTimer;

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _busSubscription;
  StreamSubscription<QuerySnapshot>? _bookingSubscription;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Callbacks for different data updates
  VoidCallback? _onBusDataUpdate;
  VoidCallback? _onBookingUpdate;
  VoidCallback? _onLocationUpdate;
  VoidCallback? _onGeneralDataUpdate;

  // Start automatic refresh for bus data
  void startBusRefresh(
      {VoidCallback? onUpdate,
      Duration interval = const Duration(minutes: 2)}) {
    _onBusDataUpdate = onUpdate;
    _busRefreshTimer?.cancel();
    _busRefreshTimer = Timer.periodic(interval, (timer) {
      _onBusDataUpdate?.call();
    });
  }

  // Start automatic refresh for booking data
  void startBookingRefresh(
      {VoidCallback? onUpdate,
      Duration interval = const Duration(minutes: 1)}) {
    _onBookingUpdate = onUpdate;
    _bookingRefreshTimer?.cancel();
    _bookingRefreshTimer = Timer.periodic(interval, (timer) {
      _onBookingUpdate?.call();
    });
  }

  // Start automatic refresh for location data
  void startLocationRefresh(
      {VoidCallback? onUpdate,
      Duration interval = const Duration(seconds: 30)}) {
    _onLocationUpdate = onUpdate;
    _locationRefreshTimer?.cancel();
    _locationRefreshTimer = Timer.periodic(interval, (timer) {
      _onLocationUpdate?.call();
    });
  }

  // Start general data refresh
  void startGeneralDataRefresh(
      {VoidCallback? onUpdate,
      Duration interval = const Duration(minutes: 5)}) {
    _onGeneralDataUpdate = onUpdate;
    _generalDataTimer?.cancel();
    _generalDataTimer = Timer.periodic(interval, (timer) {
      _onGeneralDataUpdate?.call();
    });
  }

  // Start periodic ETA updates for all active bookings of the user
  void startEtaUpdatesForUser(String userId,
      {Duration interval = const Duration(seconds: 50)}) {
    _etaUpdateTimer?.cancel();
    _etaUpdateTimer = Timer.periodic(interval, (timer) async {
      print('[ETA Update] Fetching active bookings for user: $userId');
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'confirmed')
          .get();
      for (var doc in bookingsSnapshot.docs) {
        final booking = doc.data();
        final bookingId = doc.id;
        final busId = booking['busId'];
        final pickup = booking['pickupLocation'];
        if (busId == null || pickup == null) {
          print(
              '[ETA Update] Skipping booking $bookingId: missing busId or pickupLocation');
          continue;
        }
        // Fetch latest bus location
        final busDoc = await FirebaseFirestore.instance
            .collection('buses')
            .doc(busId)
            .get();
        if (!busDoc.exists || busDoc.data()?['currentLocation'] == null) {
          print(
              '[ETA Update] Skipping booking $bookingId: bus location unavailable');
          continue;
        }
        final busLoc = busDoc.data()!['currentLocation'];
        final busLatLng = LatLng(busLoc['latitude'], busLoc['longitude']);
        final pickupLatLng = LatLng(pickup['latitude'], pickup['longitude']);
        print(
            '[ETA Update] Calculating ETA for booking $bookingId (bus $busId)...');
        final directions = await DirectionsRepository().getDirections(
          origin: busLatLng,
          destination: pickupLatLng,
        );
        final eta = directions?.totalDuration;
        print('[ETA Update] ETA for booking $bookingId: $eta');
        if (eta != null) {
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .update({'eta': eta, 'updatedAt': FieldValue.serverTimestamp()});
          print('[ETA Update] ETA updated in Firestore for booking $bookingId');
        }
      }
    });
  }

  // Stop periodic ETA updates
  void stopEtaUpdates() {
    _etaUpdateTimer?.cancel();
    _etaUpdateTimer = null;
  }

  // Set up real-time bus monitoring
  void setupBusMonitoring(String busId, Function(BusModel) onBusUpdate) {
    _busSubscription?.cancel();
    _busSubscription = FirebaseFirestore.instance
        .collection('buses')
        .where('busId', isEqualTo: busId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final busData = BusModel.fromJson(doc.data(), doc.id);
        onBusUpdate(busData);
      }
    });
  }

  // Set up real-time booking monitoring
  void setupBookingMonitoring(
      String userId, Function(List<Map<String, dynamic>>) onBookingUpdate) {
    _bookingSubscription?.cancel();
    _bookingSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'confirmed')
        .snapshots()
        .listen((snapshot) {
      final bookings = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      onBookingUpdate(bookings);
    });
  }

  // Set up real-time user monitoring
  void setupUserMonitoring(
      String userId, Function(Map<String, dynamic>) onUserUpdate) {
    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        onUserUpdate(snapshot.data()!);
      }
    });
  }

  // Stop all refresh timers
  void stopAllRefresh() {
    _busRefreshTimer?.cancel();
    _bookingRefreshTimer?.cancel();
    _locationRefreshTimer?.cancel();
    _generalDataTimer?.cancel();
    _etaUpdateTimer?.cancel();

    _busSubscription?.cancel();
    _bookingSubscription?.cancel();
    _userSubscription?.cancel();
  }

  // Stop specific refresh
  void stopBusRefresh() {
    _busRefreshTimer?.cancel();
    _onBusDataUpdate = null;
  }

  void stopBookingRefresh() {
    _bookingRefreshTimer?.cancel();
    _onBookingUpdate = null;
  }

  void stopLocationRefresh() {
    _locationRefreshTimer?.cancel();
    _onLocationUpdate = null;
  }

  void stopGeneralDataRefresh() {
    _generalDataTimer?.cancel();
    _onGeneralDataUpdate = null;
  }

  // Dispose all resources
  void dispose() {
    stopAllRefresh();
  }
}

// Mixin for automatic refresh functionality
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  final AutoRefreshService _refreshService = AutoRefreshService();

  @override
  void dispose() {
    _refreshService.dispose();
    super.dispose();
  }

  // Start automatic refresh for this screen
  void startAutoRefresh({
    VoidCallback? onBusUpdate,
    VoidCallback? onBookingUpdate,
    VoidCallback? onLocationUpdate,
    VoidCallback? onGeneralDataUpdate,
  }) {
    if (onBusUpdate != null) {
      _refreshService.startBusRefresh(onUpdate: onBusUpdate);
    }
    if (onBookingUpdate != null) {
      _refreshService.startBookingRefresh(onUpdate: onBookingUpdate);
    }
    if (onLocationUpdate != null) {
      _refreshService.startLocationRefresh(onUpdate: onLocationUpdate);
    }
    if (onGeneralDataUpdate != null) {
      _refreshService.startGeneralDataRefresh(onUpdate: onGeneralDataUpdate);
    }
  }

  // Stop automatic refresh for this screen
  void stopAutoRefresh() {
    _refreshService.stopAllRefresh();
  }
}





