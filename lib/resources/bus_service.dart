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

  // Update bus current location
  Future<bool> updateBusLocation(
    String busId,
    double latitude,
    double longitude,
  ) async {
    try {
      await _firestore.collection('buses').doc(busId).update({
        'currentLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
      return true;
    } catch (e) {
      print('Error updating bus location: $e');
      return false;
    }
  }

  // Get bus current location
  Future<Map<String, dynamic>?> getBusLocation(String busId) async {
    try {
      final doc = await _firestore.collection('buses').doc(busId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['currentLocation'];
      }
      return null;
    } catch (e) {
      print('Error getting bus location: $e');
      return null;
    }
  }
}

