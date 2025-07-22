//Interact with Google Maps or TSP logic
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart';

class LatLng {
  final double latitude;
  final double longitude;
  
  LatLng(this.latitude, this.longitude);
  
  @override
  String toString() => 'LatLng($latitude, $longitude)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LatLng && 
           other.latitude == latitude && 
           other.longitude == longitude;
  }
  
  @override
  int get hashCode => Object.hash(latitude, longitude);
}

class BusStop {
  final String id;
  final LatLng location;
  final String name;
  final DateTime addedAt;
  
  BusStop({
    required this.id,
    required this.location,
    required this.name,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();
  
  @override
  String toString() => 'BusStop(id: $id, name: $name, location: $location)';
}

class OptimizedRoute {
  final List<BusStop> stops;
  final List<int> routeOrder;
  final double totalDistance;
  final double estimatedTime; // in minutes
  final DateTime optimizedAt;
  
  OptimizedRoute({
    required this.stops,
    required this.routeOrder,
    required this.totalDistance,
    required this.estimatedTime,
    DateTime? optimizedAt,
  }) : optimizedAt = optimizedAt ?? DateTime.now();
  
  List<BusStop> get orderedStops {
    return routeOrder.map((index) => 
      index < stops.length ? stops[index] : stops.first
    ).toList();
  }
  
  List<LatLng> get routeCoordinates {
    return orderedStops.map((stop) => stop.location).toList();
  }
}

class BusRouteSOM {
  List<LatLng> coordinates;
  double learningRate;
  int iterations;
  double neuronsFactor;
  
  List<LatLng> neurons = [];
  int get neuronsCount => math.max(10, (neuronsFactor * coordinates.length).round());
  
  BusRouteSOM({
    required this.coordinates,
    this.learningRate = 0.8,
    this.iterations = 500,
    this.neuronsFactor = 2.5,
  }) {
    _initializeNeurons();
  }
  
  void _initializeNeurons() {
    if (coordinates.isEmpty) return;
    
    // Calculate center point
    double centerLat = coordinates.map((c) => c.latitude).reduce((a, b) => a + b) / coordinates.length;
    double centerLon = coordinates.map((c) => c.longitude).reduce((a, b) => a + b) / coordinates.length;
    
    // Find maximum distance from center
    double maxDist = 0;
    for (var coord in coordinates) {
      double dist = _haversineDistance(centerLat, centerLon, coord.latitude, coord.longitude);
      maxDist = math.max(maxDist, dist);
    }
    
    // Initialize neurons in a circle around the center
    neurons.clear();
    for (int i = 0; i < neuronsCount; i++) {
      double angle = 2 * math.pi * i / neuronsCount;
      double radius = maxDist * 1.1; // Slightly larger than max distance
      
      // Convert km to degrees (approximate)
      double latOffset = (radius * math.cos(angle)) / 111.32;
      double lonOffset = (radius * math.sin(angle)) / (111.32 * math.cos(_toRadians(centerLat)));
      
      neurons.add(LatLng(centerLat + latOffset, centerLon + lonOffset));
    }
  }
  
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    double lat1Rad = _toRadians(lat1);
    double lon1Rad = _toRadians(lon1);
    double lat2Rad = _toRadians(lat2);
    double lon2Rad = _toRadians(lon2);
    
    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * 
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.asin(math.sqrt(a));
    return 6371 * c; // Earth's radius in km
  }
  
  double _toRadians(double degrees) => degrees * math.pi / 180;
  
  int _findBestMatchingUnit(LatLng inputPoint) {
    double minDist = double.infinity;
    int bmuIndex = 0;
    
    for (int i = 0; i < neurons.length; i++) {
      double dist = _haversineDistance(
        inputPoint.latitude, inputPoint.longitude,
        neurons[i].latitude, neurons[i].longitude
      );
      if (dist < minDist) {
        minDist = dist;
        bmuIndex = i;
      }
    }
    
    return bmuIndex;
  }
  
  void _updateNeurons(LatLng inputPoint, int bmuIndex, int iteration) {
    double currentLearningRate = learningRate * math.exp(-iteration / iterations);
    double neighborhoodRadius = (neuronsCount / 2.0) * math.exp(-iteration / iterations);
    
    for (int i = 0; i < neurons.length; i++) {
      // Calculate circular distance between neurons
      int distance = math.min(
        (i - bmuIndex).abs(),
        neuronsCount - (i - bmuIndex).abs()
      );
      
      if (distance <= neighborhoodRadius) {
        // Calculate neighborhood influence
        double influence = math.exp(-(distance * distance) / (2 * neighborhoodRadius * neighborhoodRadius));
        double learningEffect = currentLearningRate * influence;
        
        // Update neuron position
        double newLat = neurons[i].latitude + learningEffect * (inputPoint.latitude - neurons[i].latitude);
        double newLon = neurons[i].longitude + learningEffect * (inputPoint.longitude - neurons[i].longitude);
        
        neurons[i] = LatLng(newLat, newLon);
      }
    }
  }
  
  Future<void> train() async {
    final random = math.Random();
    
    for (int iteration = 0; iteration < iterations; iteration++) {
      if (coordinates.isEmpty) break;
      
      // Select random input point
      int randomIndex = random.nextInt(coordinates.length);
      LatLng inputPoint = coordinates[randomIndex];
      
      // Find best matching unit
      int bmuIndex = _findBestMatchingUnit(inputPoint);
      
      // Update neurons
      _updateNeurons(inputPoint, bmuIndex, iteration);
      
      // Yield control for UI responsiveness
      if (iteration % 25 == 0) {
        await Future.delayed(Duration(microseconds: 100));
      }
    }
  }
  
  List<int> extractOptimalRoute() {
    if (coordinates.isEmpty) return [];
    
    // Map each city to its closest neuron
    List<MapEntry<int, int>> cityToNeuron = [];
    for (int i = 0; i < coordinates.length; i++) {
      int closestNeuron = _findBestMatchingUnit(coordinates[i]);
      cityToNeuron.add(MapEntry(i, closestNeuron));
    }
    
    // Sort cities by their neuron positions to get initial tour
    cityToNeuron.sort((a, b) => a.value.compareTo(b.value));
    List<int> route = cityToNeuron.map((e) => e.key).toList();
    
    // Apply 2-opt improvement
    route = _improve2Opt(route);
    
    // Ensure circular route
    if (route.isNotEmpty && route.first != route.last) {
      route.add(route.first);
    }
    
    return route;
  }
  
  List<int> _improve2Opt(List<int> route) {
    if (route.length < 4) return route;
    
    List<int> bestRoute = List.from(route);
    double bestDistance = _calculateRouteDistance(bestRoute + [bestRoute.first]);
    
    bool improved = true;
    int maxIterations = 50; // Limit for mobile performance
    int iterations = 0;
    
    while (improved && iterations < maxIterations) {
      improved = false;
      iterations++;
      
      for (int i = 0; i < route.length - 1; i++) {
        for (int j = i + 2; j < route.length; j++) {
          if (j == route.length - 1 && i == 0) continue;
          
          // Create new route by reversing segment
          List<int> newRoute = List.from(route);
          _reverseSegment(newRoute, i + 1, j);
          
          double newDistance = _calculateRouteDistance(newRoute + [newRoute.first]);
          
          if (newDistance < bestDistance) {
            bestDistance = newDistance;
            bestRoute = newRoute;
            route = newRoute;
            improved = true;
          }
        }
      }
    }
    
    return bestRoute;
  }
  
  void _reverseSegment(List<int> route, int start, int end) {
    while (start < end) {
      int temp = route[start];
      route[start] = route[end];
      route[end] = temp;
      start++;
      end--;
    }
  }
  
  double _calculateRouteDistance(List<int> route) {
    double totalDistance = 0;
    for (int i = 0; i < route.length - 1; i++) {
      LatLng point1 = coordinates[route[i]];
      LatLng point2 = coordinates[route[i + 1]];
      totalDistance += _haversineDistance(
        point1.latitude, point1.longitude,
        point2.latitude, point2.longitude
      );
    }
    return totalDistance;
  }
  
  double _estimateTime(double distance) {
    // Assume average city bus speed of 25 km/h including stops
    const double averageSpeed = 25.0;
    return (distance / averageSpeed) * 60; // Convert to minutes
  }
  
  Future<OptimizedRoute> optimizeRoute(List<BusStop> stops) async {
    coordinates = stops.map((stop) => stop.location).toList();
    
    if (coordinates.length < 2) {
      return OptimizedRoute(
        stops: stops,
        routeOrder: stops.asMap().keys.toList(),
        totalDistance: 0,
        estimatedTime: 0,
      );
    }
    
    _initializeNeurons();
    await train();
    
    List<int> route = extractOptimalRoute();
    double distance = _calculateRouteDistance(route);
    double estimatedTime = _estimateTime(distance);
    
    return OptimizedRoute(
      stops: stops,
      routeOrder: route,
      totalDistance: distance,
      estimatedTime: estimatedTime,
    );
  }
}

class DynamicBusRouteManager extends ChangeNotifier {
  final List<BusStop> _busStops = [];
  OptimizedRoute? _currentRoute;
  bool _isOptimizing = false;
  Timer? _optimizationTimer;
  
  // Configuration
  final Duration reoptimizationDelay = Duration(seconds: 2);
  final int maxStopsForFullOptimization = 30;
  
  List<BusStop> get busStops => List.unmodifiable(_busStops);
  OptimizedRoute? get currentRoute => _currentRoute;
  bool get isOptimizing => _isOptimizing;
  
  void addBusStop(BusStop stop) {
    // Check if stop already exists
    if (_busStops.any((s) => s.id == stop.id)) {
      debugPrint('Bus stop with id ${stop.id} already exists');
      return;
    }
    
    _busStops.add(stop);
    notifyListeners();
    
    debugPrint('Added bus stop: ${stop.name} at ${stop.location}');
    _scheduleReoptimization();
  }
  
  void removeBusStop(String stopId) {
    final initialCount = _busStops.length;
    _busStops.removeWhere((stop) => stop.id == stopId);
    
    if (_busStops.length < initialCount) {
      debugPrint('Removed bus stop with id: $stopId');
      notifyListeners();
      
      if (_busStops.isEmpty) {
        _currentRoute = null;
        _optimizationTimer?.cancel();
      } else {
        _scheduleReoptimization();
      }
    }
  }
  
  void updateBusStop(BusStop updatedStop) {
    final index = _busStops.indexWhere((stop) => stop.id == updatedStop.id);
    if (index != -1) {
      _busStops[index] = updatedStop;
      notifyListeners();
      _scheduleReoptimization();
    }
  }
  
  void _scheduleReoptimization() {
    _optimizationTimer?.cancel();
    
    _optimizationTimer = Timer(reoptimizationDelay, () {
      _optimizeRoute();
    });
  }
  
  Future<void> _optimizeRoute() async {
    if (_busStops.isEmpty || _isOptimizing) return;
    
    _isOptimizing = true;
    notifyListeners();
    
    try {
      final stopwatch = Stopwatch()..start();
      
      if (_busStops.length > maxStopsForFullOptimization) {
        _currentRoute = await _lightOptimization();
      } else {
        _currentRoute = await _fullOptimization();
      }
      
      stopwatch.stop();
      debugPrint('Route optimization completed in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('Total distance: ${_currentRoute?.totalDistance.toStringAsFixed(2)} km');
      debugPrint('Estimated time: ${_currentRoute?.estimatedTime.toStringAsFixed(1)} minutes');
      
    } catch (e) {
      debugPrint('Optimization error: $e');
    } finally {
      _isOptimizing = false;
      notifyListeners();
    }
  }
  
  Future<OptimizedRoute> _fullOptimization() async {
    final som = BusRouteSOM(
      coordinates: _busStops.map((stop) => stop.location).toList(),
      iterations: 500,
      learningRate: 0.8,
      neuronsFactor: 2.5,
    );
    
    return await som.optimizeRoute(_busStops);
  }
  
  Future<OptimizedRoute> _lightOptimization() async {
    final som = BusRouteSOM(
      coordinates: _busStops.map((stop) => stop.location).toList(),
      iterations: 250,
      learningRate: 0.6,
      neuronsFactor: 2.0,
    );
    
    return await som.optimizeRoute(_busStops);
  }
  
  Future<void> forceOptimization() async {
    if (_busStops.isEmpty) return;
    await _optimizeRoute();
  }
  
  void clearAllStops() {
    _busStops.clear();
    _currentRoute = null;
    _optimizationTimer?.cancel();
    notifyListeners();
    debugPrint('All bus stops cleared');
  }
  
  // Get current position of a specific passenger in the route
  int? getPassengerPosition(String passengerId) {
    if (_currentRoute == null) return null;
    
    final stopIndex = _busStops.indexWhere((stop) => stop.id == passengerId);
    if (stopIndex == -1) return null;
    
    return _currentRoute!.routeOrder.indexOf(stopIndex);
  }
  
  // Get estimated time for a specific passenger
  double? getEstimatedTimeForPassenger(String passengerId) {
    if (_currentRoute == null) return null;
    
    final position = getPassengerPosition(passengerId);
    if (position == null) return null;
    
    // Rough estimate: divide total time by number of stops and multiply by position
    return (_currentRoute!.estimatedTime / _busStops.length) * (position + 1);
  }
  
  @override
  void dispose() {
    _optimizationTimer?.cancel();
    super.dispose();
  }
}

class BusRouteService {
  static final BusRouteService _instance = BusRouteService._internal();
  factory BusRouteService() => _instance;
  BusRouteService._internal();
  
  final DynamicBusRouteManager _routeManager = DynamicBusRouteManager();
  
  DynamicBusRouteManager get routeManager => _routeManager;
  
  // Add a passenger pickup location
  void addPassengerPickup(String passengerId, LatLng location, String locationName) {
    final stop = BusStop(
      id: passengerId,
      location: location,
      name: locationName,
    );
    
    _routeManager.addBusStop(stop);
  }
  
  // Remove a passenger pickup location
  void removePassengerPickup(String passengerId) {
    _routeManager.removeBusStop(passengerId);
  }
  
  // Update passenger location
  void updatePassengerLocation(String passengerId, LatLng newLocation, String locationName) {
    final updatedStop = BusStop(
      id: passengerId,
      location: newLocation,
      name: locationName,
    );
    
    _routeManager.updateBusStop(updatedStop);
  }
  
  // Get optimized route coordinates for Google Maps
  List<LatLng> getOptimizedRouteCoordinates() {
    final route = _routeManager.currentRoute;
    if (route == null) return [];
    
    return route.routeCoordinates;
  }
  
  // Get ordered list of bus stops
  List<BusStop> getOrderedBusStops() {
    final route = _routeManager.currentRoute;
    if (route == null) return [];
    
    return route.orderedStops;
  }
  
  // Get estimated total distance
  double? getEstimatedTotalDistance() {
    return _routeManager.currentRoute?.totalDistance;
  }
  
  // Get estimated total time
  double? getEstimatedTotalTime() {
    return _routeManager.currentRoute?.estimatedTime;
  }
  
  // Get passenger's position in route
  int? getPassengerPosition(String passengerId) {
    return _routeManager.getPassengerPosition(passengerId);
  }
  
  // Get estimated time for specific passenger
  double? getEstimatedTimeForPassenger(String passengerId) {
    return _routeManager.getEstimatedTimeForPassenger(passengerId);
  }
  
  // Force immediate optimization
  Future<void> optimizeNow() async {
    await _routeManager.forceOptimization();
  }
  
  // Clear all passengers
  void clearAllPassengers() {
    _routeManager.clearAllStops();
  }
  
  // Get current optimization status
  bool get isOptimizing => _routeManager.isOptimizing;
  
  // Get number of current passengers
  int get passengerCount => _routeManager.busStops.length;
}

