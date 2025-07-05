import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/foundation.dart';

class LatLng {
  final double latitude;
  final double longitude;
  
  LatLng(this.latitude, this.longitude);
  
  @override
  String toString() => 'LatLng($latitude, $longitude)';
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
}

class OptimizedRoute {
  final List<BusStop> stops;
  final List<int> routeOrder;
  final double totalDistance;
  final DateTime optimizedAt;
  
  OptimizedRoute({
    required this.stops,
    required this.routeOrder,
    required this.totalDistance,
    DateTime? optimizedAt,
  }) : optimizedAt = optimizedAt ?? DateTime.now();
}

class BusRouteSOM {
  List<LatLng> coordinates;
  double learningRate;
  int iterations;
  double neuronsFactor;
  
  List<LatLng> neurons = [];
  int get neuronsCount => (neuronsFactor * coordinates.length).round();
  
  BusRouteSOM({
    required this.coordinates,
    this.learningRate = 0.8,
    this.iterations = 500, // Reduced for mobile performance
    this.neuronsFactor = 2.5,
  }) {
    _initializeNeurons();
  }
  
  void _initializeNeurons() {
    if (coordinates.isEmpty) return;
    
    // Find center and radius
    double centerLat = coordinates.map((c) => c.latitude).reduce((a, b) => a + b) / coordinates.length;
    double centerLon = coordinates.map((c) => c.longitude).reduce((a, b) => a + b) / coordinates.length;
    
    double maxDist = 0;
    for (var coord in coordinates) {
      double dist = _haversineDistance(centerLat, centerLon, coord.latitude, coord.longitude);
      maxDist = math.max(maxDist, dist);
    }
    
    // Create neurons in a circle
    neurons.clear();
    for (int i = 0; i < neuronsCount; i++) {
      double angle = 2 * math.pi * i / neuronsCount;
      double radius = maxDist * 1.2;
      
      double lat = centerLat + (radius * math.cos(angle)) / 111.32;
      double lon = centerLon + (radius * math.sin(angle)) / (111.32 * math.cos(_toRadians(centerLat)));
      
      neurons.add(LatLng(lat, lon));
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
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.asin(math.sqrt(a));
    return 6371 * c; // Earth's radius in km
  }
  
  double _toRadians(double degrees) => degrees * math.pi / 180;
  
  int _findClosestNeuron(LatLng city) {
    double minDist = double.infinity;
    int closestIdx = 0;
    
    for (int i = 0; i < neurons.length; i++) {
      double dist = _haversineDistance(
        city.latitude, city.longitude,
        neurons[i].latitude, neurons[i].longitude
      );
      if (dist < minDist) {
        minDist = dist;
        closestIdx = i;
      }
    }
    
    return closestIdx;
  }
  
  void _updateNeurons(LatLng city, int winnerIdx, int iteration) {
    double currentLearningRate = learningRate * (1 - iteration / iterations);
    int neighborhoodSize = math.max(1, (neuronsCount * (1 - iteration / iterations) / 4).round());
    
    for (int i = 0; i < neurons.length; i++) {
      // Calculate circular distance
      int dist = math.min((i - winnerIdx).abs(), neuronsCount - (i - winnerIdx).abs());
      
      if (dist <= neighborhoodSize) {
        double influence = currentLearningRate * math.exp(-dist * dist / (2 * neighborhoodSize * neighborhoodSize));
        
        // Update neuron position
        double newLat = neurons[i].latitude + influence * (city.latitude - neurons[i].latitude);
        double newLon = neurons[i].longitude + influence * (city.longitude - neurons[i].longitude);
        
        neurons[i] = LatLng(newLat, newLon);
      }
    }
  }
  
  Future<void> train() async {
    final random = math.Random();
    
    for (int iteration = 0; iteration < iterations; iteration++) {
      if (coordinates.isEmpty) break;
      
      // Randomly select a city
      int cityIdx = random.nextInt(coordinates.length);
      LatLng city = coordinates[cityIdx];
      
      // Find winner neuron
      int winnerIdx = _findClosestNeuron(city);
      
      // Update neurons
      _updateNeurons(city, winnerIdx, iteration);
      
      // Yield control occasionally for UI responsiveness
      if (iteration % 50 == 0) {
        await Future.delayed(Duration(milliseconds: 1));
      }
    }
  }
  
  List<int> getRoute() {
    List<MapEntry<int, int>> cityToNeuron = [];
    
    for (int i = 0; i < coordinates.length; i++) {
      int closestNeuron = _findClosestNeuron(coordinates[i]);
      cityToNeuron.add(MapEntry(i, closestNeuron));
    }
    
    // Sort by neuron position
    cityToNeuron.sort((a, b) => a.value.compareTo(b.value));
    
    List<int> route = cityToNeuron.map((e) => e.key).toList();
    route.add(route[0]); // Return to start
    
    return route;
  }
  
  double calculateRouteDistance(List<int> route) {
    double totalDistance = 0;
    for (int i = 0; i < route.length - 1; i++) {
      LatLng city1 = coordinates[route[i]];
      LatLng city2 = coordinates[route[i + 1]];
      totalDistance += _haversineDistance(city1.latitude, city1.longitude, city2.latitude, city2.longitude);
    }
    return totalDistance;
  }
  
  Future<OptimizedRoute> optimizeRoute(List<BusStop> stops) async {
    coordinates = stops.map((stop) => stop.location).toList();
    
    if (coordinates.length < 2) {
      return OptimizedRoute(
        stops: stops,
        routeOrder: stops.asMap().keys.toList(),
        totalDistance: 0,
      );
    }
    
    _initializeNeurons();
    await train();
    
    List<int> route = getRoute();
    double distance = calculateRouteDistance(route);
    
    return OptimizedRoute(
      stops: stops,
      routeOrder: route,
      totalDistance: distance,
    );
  }
}

class DynamicBusRouteManager extends ChangeNotifier {
  List<BusStop> _busStops = [];
  OptimizedRoute? _currentRoute;
  bool _isOptimizing = false;
  Timer? _optimizationTimer;
  
  // Configuration
  final Duration reoptimizationDelay = Duration(seconds: 3);
  final int maxStopsBeforeOptimization = 50;
  
  List<BusStop> get busStops => List.unmodifiable(_busStops);
  OptimizedRoute? get currentRoute => _currentRoute;
  bool get isOptimizing => _isOptimizing;
  
  void addBusStop(BusStop stop) {
    _busStops.add(stop);
    notifyListeners();
    
    // Trigger delayed reoptimization
    _scheduleReoptimization();
  }
  
  void removeBusStop(String stopId) {
    _busStops.removeWhere((stop) => stop.id == stopId);
    notifyListeners();
    
    if (_busStops.isNotEmpty) {
      _scheduleReoptimization();
    } else {
      _currentRoute = null;
    }
  }
  
  void _scheduleReoptimization() {
    // Cancel existing timer
    _optimizationTimer?.cancel();
    
    // Schedule new optimization
    _optimizationTimer = Timer(reoptimizationDelay, () {
      _optimizeRoute();
    });
  }
  
  Future<void> _optimizeRoute() async {
    if (_busStops.isEmpty || _isOptimizing) return;
    
    _isOptimizing = true;
    notifyListeners();
    
    try {
      // Use compute for heavy calculations to avoid blocking UI
      if (_busStops.length > maxStopsBeforeOptimization) {
        // For large datasets, use lighter optimization
        _currentRoute = await _lightOptimization();
      } else {
        // Full SOM optimization
        _currentRoute = await _fullOptimization();
      }
      
      debugPrint('Route optimized: ${_currentRoute?.totalDistance.toStringAsFixed(2)} km');
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
    );
    
    return await som.optimizeRoute(_busStops);
  }
  
  Future<OptimizedRoute> _lightOptimization() async {
    // For many stops, use faster but less optimal approach
    final som = BusRouteSOM(
      coordinates: _busStops.map((stop) => stop.location).toList(),
      iterations: 200, // Reduced iterations
      learningRate: 0.6,
      neuronsFactor: 2.0,
    );
    
    return await som.optimizeRoute(_busStops);
  }
  
  Future<void> forceOptimization() async {
    await _optimizeRoute();
  }
  
  void clearAllStops() {
    _busStops.clear();
    _currentRoute = null;
    _optimizationTimer?.cancel();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _optimizationTimer?.cancel();
    super.dispose();
  }
}

// Usage in your Flutter app
class BusRouteService {
  static final BusRouteService _instance = BusRouteService._internal();
  factory BusRouteService() => _instance;
  BusRouteService._internal();
  
  final DynamicBusRouteManager _routeManager = DynamicBusRouteManager();
  
  DynamicBusRouteManager get routeManager => _routeManager;
  
  void addPassengerPickup(String passengerId, LatLng location, String locationName) {
    final stop = BusStop(
      id: passengerId,
      location: location,
      name: locationName,
    );
    
    _routeManager.addBusStop(stop);
  }
  
  void removePassengerPickup(String passengerId) {
    _routeManager.removeBusStop(passengerId);
  }
  
  List<LatLng> getOptimizedRouteCoordinates() {
    final route = _routeManager.currentRoute;
    if (route == null) return [];
    
    return route.routeOrder.map((index) => 
      index < route.stops.length ? route.stops[index].location : route.stops.first.location
    ).toList();
  }
  
  double? getEstimatedTotalDistance() {
    return _routeManager.currentRoute?.totalDistance;
  }
}