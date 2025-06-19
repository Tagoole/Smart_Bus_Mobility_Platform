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
}
