import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';

class AutoRefreshService {
  static final AutoRefreshService _instance = AutoRefreshService._internal();
  factory AutoRefreshService() => _instance;
  AutoRefreshService._internal();

  // Timers for different types of refresh
  Timer? _busRefreshTimer;
  Timer? _bookingRefreshTimer;
  Timer? _locationRefreshTimer;
  Timer? _generalDataTimer;

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
  void startBusRefresh({VoidCallback? onUpdate, Duration interval = const Duration(minutes: 2)}) {
    _onBusDataUpdate = onUpdate;
    _busRefreshTimer?.cancel();
    _busRefreshTimer = Timer.periodic(interval, (timer) {
      _onBusDataUpdate?.call();
    });
  }

  // Start automatic refresh for booking data
  void startBookingRefresh({VoidCallback? onUpdate, Duration interval = const Duration(minutes: 1)}) {
    _onBookingUpdate = onUpdate;
    _bookingRefreshTimer?.cancel();
    _bookingRefreshTimer = Timer.periodic(interval, (timer) {
      _onBookingUpdate?.call();
    });
  }

  // Start automatic refresh for location data
  void startLocationRefresh({VoidCallback? onUpdate, Duration interval = const Duration(seconds: 30)}) {
    _onLocationUpdate = onUpdate;
    _locationRefreshTimer?.cancel();
    _locationRefreshTimer = Timer.periodic(interval, (timer) {
      _onLocationUpdate?.call();
    });
  }

  // Start general data refresh
  void startGeneralDataRefresh({VoidCallback? onUpdate, Duration interval = const Duration(minutes: 5)}) {
    _onGeneralDataUpdate = onUpdate;
    _generalDataTimer?.cancel();
    _generalDataTimer = Timer.periodic(interval, (timer) {
      _onGeneralDataUpdate?.call();
    });
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
  void setupBookingMonitoring(String userId, Function(List<Map<String, dynamic>>) onBookingUpdate) {
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
  void setupUserMonitoring(String userId, Function(Map<String, dynamic>) onUserUpdate) {
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