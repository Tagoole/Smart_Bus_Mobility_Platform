import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String locationId;
  final String userId;
  final String locationName;
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String locationType; // 'pickup', 'destination', 'stop'
  final bool isActive;
  final String? notes;

  LocationModel({
    required this.locationId,
    required this.userId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    this.address,
    required this.createdAt,
    this.updatedAt,
    this.locationType = 'pickup',
    this.isActive = true,
    this.notes,
  });

  // Create LocationModel from Firestore document
  factory LocationModel.fromJson(Map<String, dynamic> json, String docId) {
    return LocationModel(
      locationId: docId,
      userId: json['userId'],
      locationName: json['locationName'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
      locationType: json['locationType'] ?? 'pickup',
      isActive: json['isActive'] ?? true,
      notes: json['notes'],
    );
  }

  // Convert LocationModel to Firestore-compatible JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'locationName': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'locationType': locationType,
      'isActive': isActive,
      'notes': notes,
    };
  }

  // Create a copy with updated fields
  LocationModel copyWith({
    String? locationId,
    String? userId,
    String? locationName,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? locationType,
    bool? isActive,
    String? notes,
  }) {
    return LocationModel(
      locationId: locationId ?? this.locationId,
      userId: userId ?? this.userId,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      locationType: locationType ?? this.locationType,
      isActive: isActive ?? this.isActive,
      notes: notes ?? this.notes,
    );
  }

  // Create a pickup location from coordinates
  factory LocationModel.createPickupLocation({
    required String userId,
    required double latitude,
    required double longitude,
    String? locationName,
    String? address,
    String? notes,
  }) {
    return LocationModel(
      locationId: '', // Will be set by Firestore
      userId: userId,
      locationName: locationName ?? 'Pickup Location',
      latitude: latitude,
      longitude: longitude,
      address: address,
      createdAt: DateTime.now(),
      locationType: 'pickup',
      isActive: true,
      notes: notes,
    );
  }

  // Get coordinates as LatLng (for Google Maps)
  Map<String, double> get coordinates => {
    'latitude': latitude,
    'longitude': longitude,
  };

  // Check if location is valid
  bool get isValid =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  @override
  String toString() {
    return 'LocationModel(locationId: $locationId, locationName: $locationName, coordinates: ($latitude, $longitude), type: $locationType)';
  }
}











