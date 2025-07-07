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
  final Map<String, dynamic>? bookedSeats; // Track booked seats: {seatNumber: userId}

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
  });

  factory BusModel.fromJson(Map<String, dynamic> json, String docId) {
    return BusModel(
      busId: docId,
      numberPlate: json['numberPlate'],
      vehicleModel: json['vehicleModel'],
      driverId: json['driverId'],
      seatCapacity: json['seatCapacity'],
      routeId: json['routeId'],
      startPoint: json['startPoint'],
      destination: json['destination'],
      isAvailable: json['isAvailable'] ?? true,
      availableSeats: json['availableSeats'] ?? json['seatCapacity'],
      fare: (json['fare'] as num).toDouble(),
      departureTime: json['departureTime'] != null
          ? DateTime.parse(json['departureTime'])
          : null,
      estimatedArrival: json['estimatedArrival'] != null
          ? DateTime.parse(json['estimatedArrival'])
          : null,
      bookedSeats: json['bookedSeats'] ?? {},
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
}
