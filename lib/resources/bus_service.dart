import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all available buses
  Future<List<BusModel>> getAvailableBuses() async {
    try {
      final snapshot = await _firestore
          .collection('buses')
          .where('isAvailable', isEqualTo: true)
          .where('availableSeats', isGreaterThan: 0)
          .get();

      return snapshot.docs
          .map((doc) => BusModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting available buses: $e');
      return [];
    }
  }

  // Get buses by destination
  Future<List<BusModel>> getBusesByDestination(String destination) async {
    try {
      final snapshot = await _firestore
          .collection('buses')
          .where('isAvailable', isEqualTo: true)
          .where('availableSeats', isGreaterThan: 0)
          .where('destination', isEqualTo: destination)
          .get();

      return snapshot.docs
          .map((doc) => BusModel.fromJson(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error getting buses by destination: $e');
      return [];
    }
  }

  // Get buses near a location
  Future<List<BusModel>> getBusesNearLocation(
    LatLng location,
    double radiusKm,
  ) async {
    try {
      // This is a simplified version. In a real app, you'd use geospatial queries
      final snapshot = await _firestore
          .collection('buses')
          .where('isAvailable', isEqualTo: true)
          .where('availableSeats', isGreaterThan: 0)
          .get();

      final buses = snapshot.docs
          .map((doc) => BusModel.fromJson(doc.data(), doc.id))
          .toList();

      // Filter buses by distance (simplified - in real app use proper geospatial queries)
      return buses.where((bus) {
        // For now, return all buses. In production, implement proper distance calculation
        return true;
      }).toList();
    } catch (e) {
      print('Error getting buses near location: $e');
      return [];
    }
  }

  // Book a seat on a bus
  Future<bool> bookSeat(
    String busId,
    String userId,
    LatLng pickupLocation,
  ) async {
    try {
      // Get the bus document
      final busDoc = await _firestore.collection('buses').doc(busId).get();
      if (!busDoc.exists) {
        print('Bus not found');
        return false;
      }

      final busData = busDoc.data() as Map<String, dynamic>;
      final availableSeats = busData['availableSeats'] ?? 0;

      if (availableSeats <= 0) {
        print('No available seats');
        return false;
      }

      // Start a batch write
      final batch = _firestore.batch();

      // Update bus available seats
      batch.update(_firestore.collection('buses').doc(busId), {
        'availableSeats': availableSeats - 1,
      });

      // Create booking record
      final bookingRef = _firestore.collection('bookings').doc();
      batch.set(bookingRef, {
        'userId': userId,
        'busId': busId,
        'pickupLocation': {
          'latitude': pickupLocation.latitude,
          'longitude': pickupLocation.longitude,
        },
        'bookingTime': FieldValue.serverTimestamp(),
        'status': 'confirmed',
        'fare': busData['fare'],
      });

      // Commit the batch
      await batch.commit();
      return true;
    } catch (e) {
      print('Error booking seat: $e');
      return false;
    }
  }

  // Get user's active bookings
  Future<List<Map<String, dynamic>>> getUserBookings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['confirmed', 'active'])
          .orderBy('bookingTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'bookingId': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('Error getting user bookings: $e');
      return [];
    }
  }

  // Cancel a booking
  Future<bool> cancelBooking(String bookingId, String busId) async {
    try {
      final batch = _firestore.batch();

      // Update booking status
      batch.update(_firestore.collection('bookings').doc(bookingId), {
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Increase available seats on bus
      final busDoc = await _firestore.collection('buses').doc(busId).get();
      if (busDoc.exists) {
        final busData = busDoc.data() as Map<String, dynamic>;
        final currentSeats = busData['availableSeats'] ?? 0;
        batch.update(_firestore.collection('buses').doc(busId), {
          'availableSeats': currentSeats + 1,
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

  // Create sample buses for testing
  Future<void> createSampleBuses() async {
    try {
      final sampleBuses = [
        {
          'numberPlate': 'UAB 123A',
          'vehicleModel': 'Toyota Coaster',
          'driverId': 'driver1',
          'seatCapacity': 25,
          'routeId': 'route1',
          'startPoint': 'Kampala',
          'destination': 'Entebbe',
          'isAvailable': true,
          'availableSeats': 20,
          'fare': 5000.0,
          'departureTime': DateTime.now()
              .add(Duration(minutes: 30))
              .toIso8601String(),
          'estimatedArrival': DateTime.now()
              .add(Duration(hours: 1))
              .toIso8601String(),
        },
        {
          'numberPlate': 'UAB 456B',
          'vehicleModel': 'Isuzu NPR',
          'driverId': 'driver2',
          'seatCapacity': 30,
          'routeId': 'route2',
          'startPoint': 'Kampala',
          'destination': 'Jinja',
          'isAvailable': true,
          'availableSeats': 25,
          'fare': 8000.0,
          'departureTime': DateTime.now()
              .add(Duration(minutes: 45))
              .toIso8601String(),
          'estimatedArrival': DateTime.now()
              .add(Duration(hours: 2))
              .toIso8601String(),
        },
        {
          'numberPlate': 'UAB 789C',
          'vehicleModel': 'Mercedes Sprinter',
          'driverId': 'driver3',
          'seatCapacity': 15,
          'routeId': 'route3',
          'startPoint': 'Kampala',
          'destination': 'Mukono',
          'isAvailable': true,
          'availableSeats': 12,
          'fare': 3000.0,
          'departureTime': DateTime.now()
              .add(Duration(minutes: 15))
              .toIso8601String(),
          'estimatedArrival': DateTime.now()
              .add(Duration(minutes: 45))
              .toIso8601String(),
        },
      ];

      for (final busData in sampleBuses) {
        await _firestore.collection('buses').add(busData);
      }
      print('Sample buses created successfully');
    } catch (e) {
      print('Error creating sample buses: $e');
    }
  }
}
