class RouteModel {
  final String routeId;
  final String routeName;
  final List<String>? stops;
  final double distance;
  final Duration estimatedTime;

  RouteModel({
    required this.routeId,
    required this.routeName,
    required this.stops,
    required this.distance,
    required this.estimatedTime,
  });

  // Convert from Firestore JSON
  factory RouteModel.fromJson(Map<String, dynamic> json, String docId) {
    return RouteModel(
      routeId: docId,
      routeName: json['routeName'],
      stops: (json['stops'] as List?)?.map((e) => e.toString()).toList(),
      distance: (json['distance'] as num).toDouble(),
      estimatedTime: Duration(minutes: json['estimatedTimeMinutes']),
    );
  }

  // Convert to Firestore JSON
  Map<String, dynamic> toJson() {
    return {
      'routeName': routeName,
      'stops': stops,
      'distance': distance,
      'estimatedTimeMinutes': estimatedTime.inMinutes,
    };
  }
}





