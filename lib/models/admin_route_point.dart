import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRoutePoint {
  final String id;
  final String busId;
  final String type; // 'start' or 'destination'
  final String address;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  AdminRoutePoint({
    required this.id,
    required this.busId,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  factory AdminRoutePoint.fromJson(Map<String, dynamic> json, String docId) {
    return AdminRoutePoint(
      id: docId,
      busId: json['busId'],
      type: json['type'],
      address: json['address'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'busId': busId,
      'type': type,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt,
    };
  }
} 













