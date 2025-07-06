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
    );
  }
}
