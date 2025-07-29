import 'package:google_maps_flutter/google_maps_flutter.dart';

class BusModel {
  final String busId;
  final String numberPlate;
  final String vehicleModel;
  final int seatCapacity;
  final String driverId;
  final String routeId;
  final String startPoint;
  final String destination;
  final bool isAvailable;
  final int availableSeats;
  final double fare;
  final DateTime? departureTime;
  final DateTime? estimatedArrival;
  final Map<String, dynamic>?
  bookedSeats; // Track booked seats: {seatNumber: userId}
  final Map<String, dynamic>?
  currentLocation; // Track current bus location: {latitude, longitude}
  final double? startLat;
  final double? startLng;
  final double? destinationLat;
  final double? destinationLng;
  final List<Map<String, dynamic>>? routePolyline; // Route polyline points
  final List<Map<String, dynamic>>?
      serviceAreaPolygon; // Service area polygon points

  BusModel({
    required this.busId,
    required this.numberPlate,
    required this.vehicleModel,
    required this.driverId,
    required this.seatCapacity,
    required this.routeId,
    required this.startPoint,
    required this.destination,
    required this.isAvailable,
    required this.availableSeats,
    required this.fare,
    this.departureTime,
    this.estimatedArrival,
    this.bookedSeats,
    this.currentLocation,
    this.startLat,
    this.startLng,
    this.destinationLat,
    this.destinationLng,
    this.routePolyline,
    this.serviceAreaPolygon,
  });

  factory BusModel.fromJson(Map<String, dynamic> json, String docId) {
    // Helper function to safely parse dates
    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;

      try {
        // Handle Firestore Timestamp
        if (dateValue is Map<String, dynamic> &&
            dateValue.containsKey('_seconds')) {
          final seconds = dateValue['_seconds'] as int;
          final nanoseconds = dateValue['_nanoseconds'] as int? ?? 0;
          return DateTime.fromMillisecondsSinceEpoch(
              seconds * 1000 + (nanoseconds / 1000000).round());
        }

        // Handle string dates
        if (dateValue is String) {
          return DateTime.parse(dateValue);
        }

        // Handle DateTime objects
        if (dateValue is DateTime) {
          return dateValue;
        }

        // Handle numeric timestamps
        if (dateValue is int) {
          return DateTime.fromMillisecondsSinceEpoch(dateValue);
        }

        return null;
      } catch (e) {
        print('Error parsing date: $dateValue, Error: $e');
        return null;
      }
    }

    return BusModel(
      busId: docId,
      numberPlate: json['numberPlate'] ?? '',
      vehicleModel: json['vehicleModel'] ?? '',
      driverId: json['driverId'] ?? '',
      seatCapacity: json['seatCapacity'] ?? 0,
      routeId: json['routeId'] ?? '',
      startPoint: json['startPoint'] ?? '',
      destination: json['destination'] ?? '',
      isAvailable: json['isAvailable'] ?? true,
      availableSeats: json['availableSeats'] ?? json['seatCapacity'] ?? 0,
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      departureTime: parseDate(json['departureTime']),
      estimatedArrival: parseDate(json['estimatedArrival']),
      bookedSeats: json['bookedSeats'] ?? {},
      currentLocation: json['currentLocation'],
      startLat: (json['startLat'] as num?)?.toDouble(),
      startLng: (json['startLng'] as num?)?.toDouble(),
      destinationLat: (json['destinationLat'] as num?)?.toDouble(),
      destinationLng: (json['destinationLng'] as num?)?.toDouble(),
      routePolyline: json['routePolyline'] != null
          ? List<Map<String, dynamic>>.from(json['routePolyline'])
          : null,
      serviceAreaPolygon: json['serviceAreaPolygon'] != null
          ? List<Map<String, dynamic>>.from(json['serviceAreaPolygon'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numberPlate': numberPlate,
      'vehicleModel': vehicleModel,
      'seatCapacity': seatCapacity,
      'driverId': driverId,
      'routeId': routeId,
      'startPoint': startPoint,
      'destination': destination,
      'isAvailable': isAvailable,
      'availableSeats': availableSeats,
      'fare': fare,
      'departureTime': departureTime?.toIso8601String(),
      'estimatedArrival': estimatedArrival?.toIso8601String(),
      'bookedSeats': bookedSeats ?? {},
      'currentLocation': currentLocation,
      'startLat': startLat,
      'startLng': startLng,
      'destinationLat': destinationLat,
      'destinationLng': destinationLng,
      'routePolyline': routePolyline,
      'serviceAreaPolygon': serviceAreaPolygon,
    };
  }

  // Create a copy with updated values
  BusModel copyWith({
    String? busId,
    String? numberPlate,
    String? vehicleModel,
    int? seatCapacity,
    String? driverId,
    String? routeId,
    String? startPoint,
    String? destination,
    bool? isAvailable,
    int? availableSeats,
    double? fare,
    DateTime? departureTime,
    DateTime? estimatedArrival,
    Map<String, dynamic>? bookedSeats,
    Map<String, dynamic>? currentLocation,
    double? startLat,
    double? startLng,
    double? destinationLat,
    double? destinationLng,
    List<Map<String, dynamic>>? routePolyline,
    List<Map<String, dynamic>>? serviceAreaPolygon,
  }) {
    return BusModel(
      busId: busId ?? this.busId,
      numberPlate: numberPlate ?? this.numberPlate,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      driverId: driverId ?? this.driverId,
      seatCapacity: seatCapacity ?? this.seatCapacity,
      routeId: routeId ?? this.routeId,
      startPoint: startPoint ?? this.startPoint,
      destination: destination ?? this.destination,
      isAvailable: isAvailable ?? this.isAvailable,
      availableSeats: availableSeats ?? this.availableSeats,
      fare: fare ?? this.fare,
      departureTime: departureTime ?? this.departureTime,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      bookedSeats: bookedSeats ?? this.bookedSeats,
      currentLocation: currentLocation ?? this.currentLocation,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      routePolyline: routePolyline ?? this.routePolyline,
      serviceAreaPolygon: serviceAreaPolygon ?? this.serviceAreaPolygon,
    );
  }

  // Helper method to check if a seat is booked
  bool isSeatBooked(int seatNumber) {
    return bookedSeats?.containsKey(seatNumber.toString()) ?? false;
  }

  // Helper method to get the user who booked a seat
  String? getSeatBooker(int seatNumber) {
    return bookedSeats?[seatNumber.toString()];
  }

  // Helper method to get current location as LatLng
  LatLng? getCurrentLocationLatLng() {
    if (currentLocation != null &&
        currentLocation!['latitude'] != null &&
        currentLocation!['longitude'] != null) {
      return LatLng(
        currentLocation!['latitude'],
        currentLocation!['longitude'],
      );
    }
    return null;
  }

  // Helper method to get route polyline points as List<LatLng>
  List<LatLng> getRoutePolylinePoints() {
    if (routePolyline == null) return [];
    return routePolyline!.map((point) {
      return LatLng(
        (point['lat'] as num).toDouble(),
        (point['lng'] as num).toDouble(),
      );
    }).toList();
  }

  // Helper method to get service area polygon points as List<LatLng>
  List<LatLng> getServiceAreaPolygonPoints() {
    if (serviceAreaPolygon == null) return [];
    return serviceAreaPolygon!.map((point) {
      return LatLng(
        (point['lat'] as num).toDouble(),
        (point['lng'] as num).toDouble(),
      );
    }).toList();
  }
}













