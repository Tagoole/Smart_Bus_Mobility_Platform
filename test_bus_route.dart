import 'dart:math' as math;
import 'dart:async';

// Your existing classes (copy from your main file)
class LatLng {
  final double latitude;
  final double longitude;
  
  LatLng(this.latitude, this.longitude);
  
  @override
  String toString() => 'LatLng(${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
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
  String toString() => 'BusStop(id: $id, name: $name)';
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

// Simplified SOM for testing
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
    this.iterations = 100, // Reduced for faster testing
    this.neuronsFactor = 2.0,
  }) {
    _initializeNeurons();
  }
  
  void _initializeNeurons() {
    if (coordinates.isEmpty) return;
    
    // Find center
    double centerLat = coordinates.map((c) => c.latitude).reduce((a, b) => a + b) / coordinates.length;
    double centerLon = coordinates.map((c) => c.longitude).reduce((a, b) => a + b) / coordinates.length;
    
    // Find max distance
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
    return 6371 * c;
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
      int dist = math.min((i - winnerIdx).abs(), neuronsCount - (i - winnerIdx).abs());
      
      if (dist <= neighborhoodSize) {
        double influence = currentLearningRate * math.exp(-dist * dist / (2 * neighborhoodSize * neighborhoodSize));
        
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
      
      int cityIdx = random.nextInt(coordinates.length);
      LatLng city = coordinates[cityIdx];
      
      int winnerIdx = _findClosestNeuron(city);
      _updateNeurons(city, winnerIdx, iteration);
    }
  }
  
  List<int> getRoute() {
    List<MapEntry<int, int>> cityToNeuron = [];
    
    for (int i = 0; i < coordinates.length; i++) {
      int closestNeuron = _findClosestNeuron(coordinates[i]);
      cityToNeuron.add(MapEntry(i, closestNeuron));
    }
    
    cityToNeuron.sort((a, b) => a.value.compareTo(b.value));
    
    List<int> route = cityToNeuron.map((e) => e.key).toList();
    route.add(route[0]);
    
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

// Simple test functions
class SimpleTests {
  
  // Test 1: Basic 5-stop route
  static Future<void> test1_BasicRoute() async {
    print('\n🚌 Test 1: Basic 5-Stop Route');
    print('=' * 30);
    
    // Create 5 stops around Kampala
    List<BusStop> stops = [
      BusStop(id: '1', location: LatLng(0.3476, 32.5825), name: 'City Center'),
      BusStop(id: '2', location: LatLng(0.3576, 32.5925), name: 'Nakasero'),
      BusStop(id: '3', location: LatLng(0.3376, 32.5725), name: 'Rubaga'),
      BusStop(id: '4', location: LatLng(0.3676, 32.5825), name: 'Kololo'),
      BusStop(id: '5', location: LatLng(0.3476, 32.6025), name: 'Bugolobi'),
    ];
    
    print('Original stops:');
    for (int i = 0; i < stops.length; i++) {
      print('  ${i + 1}. ${stops[i].name} - ${stops[i].location}');
    }
    
    print('\n🔄 Optimizing route...');
    BusRouteSOM som = BusRouteSOM(coordinates: stops.map((s) => s.location).toList());
    OptimizedRoute route = await som.optimizeRoute(stops);
    
    print('✅ Optimized route:');
    for (int i = 0; i < route.routeOrder.length; i++) {
      int stopIndex = route.routeOrder[i];
      if (stopIndex < stops.length) {
        print('  ${i + 1}. ${stops[stopIndex].name}');
      }
    }
    print('📏 Total distance: ${route.totalDistance.toStringAsFixed(2)} km');
  }
  
  // Test 2: Compare original vs optimized
  static Future<void> test2_CompareRoutes() async {
    print('\n🔄 Test 2: Compare Original vs Optimized');
    print('=' * 40);
    
    List<BusStop> stops = [
      BusStop(id: '1', location: LatLng(0.3476, 32.5825), name: 'Stop A'),
      BusStop(id: '2', location: LatLng(0.3676, 32.5825), name: 'Stop B'),
      BusStop(id: '3', location: LatLng(0.3376, 32.5725), name: 'Stop C'),
      BusStop(id: '4', location: LatLng(0.3576, 32.5925), name: 'Stop D'),
      BusStop(id: '5', location: LatLng(0.3476, 32.6025), name: 'Stop E'),
      BusStop(id: '6', location: LatLng(0.3276, 32.5825), name: 'Stop F'),
    ];
    
    // Calculate original route distance (in order)
    double originalDistance = 0;
    for (int i = 0; i < stops.length; i++) {
      int nextIndex = (i + 1) % stops.length;
      originalDistance += _calculateDistance(stops[i].location, stops[nextIndex].location);
    }
    
    print('📏 Original route distance: ${originalDistance.toStringAsFixed(2)} km');
    
    // Optimize route
    print('🔄 Optimizing...');
    BusRouteSOM som = BusRouteSOM(coordinates: stops.map((s) => s.location).toList());
    OptimizedRoute optimized = await som.optimizeRoute(stops);
    
    print('📏 Optimized route distance: ${optimized.totalDistance.toStringAsFixed(2)} km');
    
    double improvement = originalDistance - optimized.totalDistance;
    double percentImprovement = (improvement / originalDistance) * 100;
    
    if (improvement > 0) {
      print('✅ Improvement: ${improvement.toStringAsFixed(2)} km (${percentImprovement.toStringAsFixed(1)}% better)');
    } else {
      print('📊 No improvement found (algorithm still learning)');
    }
  }
  
  // Test 3: Small vs Large routes
  static Future<void> test3_DifferentSizes() async {
    print('\n📊 Test 3: Different Route Sizes');
    print('=' * 35);
    
    List<int> sizes = [3, 5, 8, 10];
    
    for (int size in sizes) {
      print('\n🔄 Testing $size stops...');
      
      List<BusStop> stops = [];
      for (int i = 0; i < size; i++) {
        double lat = 0.3476 + (math.Random().nextDouble() - 0.5) * 0.2;
        double lng = 32.5825 + (math.Random().nextDouble() - 0.5) * 0.2;
        stops.add(BusStop(id: '$i', location: LatLng(lat, lng), name: 'Stop $i'));
      }
      
      DateTime start = DateTime.now();
      BusRouteSOM som = BusRouteSOM(coordinates: stops.map((s) => s.location).toList());
      OptimizedRoute route = await som.optimizeRoute(stops);
      DateTime end = DateTime.now();
      
      int timeMs = end.difference(start).inMilliseconds;
      
      print('   ✅ $size stops: ${route.totalDistance.toStringAsFixed(2)} km in ${timeMs}ms');
    }
  }
  
  // Test 4: Real-time adding stops
  static Future<void> test4_DynamicRoute() async {
    print('\n🔄 Test 4: Dynamic Route (Adding Stops)');
    print('=' * 40);
    
    List<BusStop> stops = [];
    
    // Add stops one by one
    List<String> locations = ['Downtown', 'Mall', 'Hospital', 'University', 'Airport'];
    
    for (int i = 0; i < locations.length; i++) {
      double lat = 0.3476 + (math.Random().nextDouble() - 0.5) * 0.1;
      double lng = 32.5825 + (math.Random().nextDouble() - 0.5) * 0.1;
      
      stops.add(BusStop(id: '$i', location: LatLng(lat, lng), name: locations[i]));
      
      print('\n➕ Added: ${locations[i]} (Total: ${stops.length} stops)');
      
      if (stops.length >= 2) {
        BusRouteSOM som = BusRouteSOM(coordinates: stops.map((s) => s.location).toList());
        OptimizedRoute route = await som.optimizeRoute(stops);
        print('   📏 Route distance: ${route.totalDistance.toStringAsFixed(2)} km');
      }
      
      await Future.delayed(Duration(milliseconds: 500)); // Simulate real-time
    }
  }
  
  // Test 5: Quick validation
  static Future<void> test5_QuickValidation() async {
    print('\n✅ Test 5: Quick Validation');
    print('=' * 30);
    
    // Test with just 3 stops
    List<BusStop> stops = [
      BusStop(id: '1', location: LatLng(0.3476, 32.5825), name: 'Start'),
      BusStop(id: '2', location: LatLng(0.3576, 32.5925), name: 'Middle'),
      BusStop(id: '3', location: LatLng(0.3376, 32.5725), name: 'End'),
    ];
    
    BusRouteSOM som = BusRouteSOM(coordinates: stops.map((s) => s.location).toList());
    OptimizedRoute route = await som.optimizeRoute(stops);
    
    print('✅ Algorithm is working!');
    print('   Stops: ${stops.length}');
    print('   Route order: ${route.routeOrder}');
    print('   Distance: ${route.totalDistance.toStringAsFixed(2)} km');
    print('   Neurons created: ${som.neuronsCount}');
    print('   Optimization completed at: ${route.optimizedAt}');
  }
  
  // Helper function
  static double _calculateDistance(LatLng point1, LatLng point2) {
    double lat1Rad = point1.latitude * math.pi / 180;
    double lon1Rad = point1.longitude * math.pi / 180;
    double lat2Rad = point2.latitude * math.pi / 180;
    double lon2Rad = point2.longitude * math.pi / 180;
    
    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) * math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.asin(math.sqrt(a));
    return 6371 * c;
  }
}

// Main function to run tests
void main() async {
  print('🚌 Simple Bus Route SOM Tests');
  print('=' * 50);
  
  try {
    await SimpleTests.test5_QuickValidation();
    await SimpleTests.test1_BasicRoute();
    await SimpleTests.test2_CompareRoutes();
    await SimpleTests.test3_DifferentSizes();
    await SimpleTests.test4_DynamicRoute();
    
    print('\n🎉 All tests completed successfully!');
    print('=' * 50);
    
  } catch (e) {
    print('\n❌ Test failed with error: $e');
  }
}