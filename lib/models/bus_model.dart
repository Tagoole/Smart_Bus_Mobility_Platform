class BusModel {
  final String busId;
  final String numberPlate;
  final String vehicleModel;
  final int seatCapacity;
  final String driverId;

  BusModel({
    required this.busId,
    required this.numberPlate,
    required this.vehicleModel,
    required this.driverId,
    required this.seatCapacity,
  });

  factory BusModel.fromJson(Map<String, dynamic> json, String docId) {
    return BusModel(
      busId: docId,
      numberPlate: json['numberPlate'],
      vehicleModel: json['vehicleModel'],
      driverId: json['driverId'],
      seatCapacity: json['seatCapacity'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numberPlate': numberPlate,
      'vehicleModel': vehicleModel,
      'seatCapacity': seatCapacity,
      'driverId': driverId,
    };
  }
}
