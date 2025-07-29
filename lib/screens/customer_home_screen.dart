import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:smart_bus_mobility_platform1/screens/passenger_map_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/current_buses_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:smart_bus_mobility_platform1/widgets/live_bus_details_sheet.dart';
import 'package:smart_bus_mobility_platform1/utils/directions_repository.dart';

class BusTrackingScreen extends StatefulWidget {
  const BusTrackingScreen({super.key});

  @override
  _BusTrackingScreenState createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen>
    with TickerProviderStateMixin {
  final int _selectedIndex = 0;
  final bool _showActiveJourney = false;
  String? _username;
  String? _profileImageUrl;
  bool _isLoadingUser = true;

  // Enhanced data for dynamic content
  List<Map<String, dynamic>> _recentBookings = [];
  Map<String, dynamic>? _userStats;
  bool _hasActiveBooking = false;
  Map<String, dynamic>? _activeBooking;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  // Automatic refresh timer
  Timer? _refreshTimer;

  // Carousel images (no state/timer/controller here)
  final List<String> _carouselImages = [
    'assets/images/bus27.jpg',
    'assets/images/bus26.jpg',
    'assets/images/bus25.jpg',
    'assets/images/bus24.jpg',
    'assets/images/bus23.jpg',
    'assets/images/bus22.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchUsername();
    _loadUserData();
    // Set up automatic refresh every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) { // Increased from 30 seconds
      if (mounted) {
        _loadUserData();
      }
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _username = doc.data()!['username'] ?? 'User';
            _profileImageUrl = doc.data()!['profileImageUrl'];
            _isLoadingUser = false;
          });
        } else {
          setState(() {
            _username = 'User';
            _profileImageUrl = null;
            _isLoadingUser = false;
          });
        }
      } catch (e) {
        print('Error fetching username: $e');
        setState(() {
          _username = 'User';
          _profileImageUrl = null;
          _isLoadingUser = false;
        });
      }
    } else {
      setState(() {
        _username = 'User';
        _profileImageUrl = null;
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Add timeout to prevent hanging
      final timeout = Future.delayed(const Duration(milliseconds: 3000));
      
      // Load recent bookings with error handling and timeout
      final bookingsFuture = FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
          
      final bookingsSnapshot = await Future.any([bookingsFuture, timeout.then((_) => null)]);

      List<Map<String, dynamic>> recentBookings = [];
      if (bookingsSnapshot != null) {
        for (var doc in bookingsSnapshot.docs) {
          final bookingData = Map<String, dynamic>.from(doc.data());
          // Add document ID to booking data for reference
          bookingData['id'] = doc.id;
          recentBookings.add(bookingData);
        }
      }

      // Check for active booking with timeout
      final activeBookingFuture = FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'confirmed')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
          
      final activeBookingSnapshot = await Future.any([activeBookingFuture, timeout.then((_) => null)]);

      Map<String, dynamic>? activeBooking;
      if (activeBookingSnapshot != null && activeBookingSnapshot.docs.isNotEmpty) {
        activeBooking =
            Map<String, dynamic>.from(activeBookingSnapshot.docs.first.data());
        activeBooking['id'] = activeBookingSnapshot.docs.first.id;
      }

      // Load user statistics with null safety
      Map<String, dynamic> userStats = {
        'totalTrips': recentBookings.length,
        'totalSpent': recentBookings.fold<double>(
          0.0,
          (sum, booking) =>
              sum + ((booking['totalFare'] as num?)?.toDouble() ?? 0.0),
        ),
        'favoriteRoute': 'Kampala → Ntinda',
        'monthlyTrips': recentBookings.where((booking) {
          final createdAt = booking['createdAt'] as Timestamp?;
          if (createdAt == null) return false;
          final now = DateTime.now();
          final bookingDate = createdAt.toDate();
          return bookingDate.month == now.month && bookingDate.year == now.year;
        }).length,
      };

      if (mounted) {
        setState(() {
          _recentBookings = recentBookings;
          _userStats = userStats;
          _hasActiveBooking = activeBooking != null;
          _activeBooking = activeBooking;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Set default values on error
      if (mounted) {
        setState(() {
          _recentBookings = [];
          _userStats = {
            'totalTrips': 0,
            'totalSpent': 0.0,
            'favoriteRoute': 'No trips yet',
            'monthlyTrips': 0,
          };
          _hasActiveBooking = false;
          _activeBooking = null;
        });
      }
    }
  }

  // Calculate ETA based on bus location and pickup location
  Future<String> _calculateETA(Map<String, dynamic> booking) async {
    try {
      final busId = booking['busId'];
      final pickupLocation = booking['pickupLocation'];

      if (busId == null || pickupLocation == null) {
        return 'N/A';
      }

      // Get current bus location
      final busDoc = await FirebaseFirestore.instance
          .collection('buses')
          .doc(busId.toString())
          .get();

      if (!busDoc.exists) {
        return 'Bus not found';
      }

      final busData = busDoc.data();
      if (busData == null) {
        return 'Bus data unavailable';
      }

      // Handle different location data formats
      double? busLat, busLng, pickupLat, pickupLng;
      final currentLocation = busData['currentLocation'];
      if (currentLocation is GeoPoint) {
        busLat = currentLocation.latitude;
        busLng = currentLocation.longitude;
      } else if (currentLocation is Map<String, dynamic>) {
        busLat = currentLocation['latitude']?.toDouble();
        busLng = currentLocation['longitude']?.toDouble();
      }
      if (pickupLocation is GeoPoint) {
        pickupLat = pickupLocation.latitude;
        pickupLng = pickupLocation.longitude;
      } else if (pickupLocation is Map<String, dynamic>) {
        pickupLat = pickupLocation['latitude']?.toDouble();
        pickupLng = pickupLocation['longitude']?.toDouble();
      }
      if (busLat == null || busLng == null || pickupLat == null || pickupLng == null) {
        return 'Location unavailable';
      }

      // Use Google Directions API for ETA
      final directions = await DirectionsRepository().getDirections(
        origin: LatLng(busLat, busLng),
        destination: LatLng(pickupLat, pickupLng),
      );
      if (directions != null) {
        return directions.totalDuration;
      }

      // Fallback: Estimate time based on straight-line distance
      double distance = _calculateDistance(busLat, busLng, pickupLat, pickupLng);
      double averageSpeedKmh = 30.0;
      double timeInHours = distance / averageSpeedKmh;
      int timeInMinutes = (timeInHours * 60).round();
      if (timeInMinutes < 1) {
        return 'Arriving now';
      } else if (timeInMinutes < 60) {
        return '$timeInMinutes min';
      } else {
        int hours = timeInMinutes ~/ 60;
        int remainingMinutes = timeInMinutes % 60;
        return '${hours}h ${remainingMinutes}m';
      }
    } catch (e) {
      print('Error calculating ETA: $e');
      return 'Unable to calculate';
    }
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  void _navigateToProfile() {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading profile...'),
          ],
        ),
      ),
    );
    
    // Navigate to profile
    Navigator.pushNamed(context, '/profile').then((_) {
      // Close loading dialog when returning from profile
      Navigator.of(context).pop();
    });
  }

  Future<void> _logout() async {
    bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (Route<dynamic> route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildBookedBusesSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error in booked buses stream: ${snapshot.error}');
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading bookings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again later',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.directions_bus_outlined,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No bookings yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start by booking your first bus!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final bookings = snapshot.data!.docs;
        print('[UI] Loaded ${bookings.length} bookings for dashboard.');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Text(
                'My Booked Buses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), // <-- Add bottom padding here
                itemCount: bookings.length,
                separatorBuilder: (context, index) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final doc = bookings[index];
                  Map<String, dynamic> booking;
                  try {
                    final data = doc.data();
                    if (data is Map<String, dynamic>) {
                      booking = Map<String, dynamic>.from(data);
                    } else {
                      booking = <String, dynamic>{};
                    }
                  } catch (e) {
                    booking = <String, dynamic>{};
                  }
                  booking['id'] = doc.id;
                  // Responsive width
                  final width = MediaQuery.of(context).size.width;
                  final cardWidth = width < 500 ? width * 0.85 : 340;
                  return GestureDetector(
                    onTap: () => _showBookingDetails(context, booking),
                    child: AnimatedOpacity(
                      opacity: 1.0,
                      duration: Duration(milliseconds: 600 + (index * 100)),
                    child: Container(
                        width: cardWidth.toDouble(),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        constraints: const BoxConstraints(
                          minHeight: 180,
                          maxHeight: 260,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.green[100]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bus image/icon
                            Padding(
                        padding: const EdgeInsets.all(16.0),
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.green[50],
                                child: Icon(Icons.directions_bus, color: Colors.green[700], size: 36),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                            booking['destination']?.toString() ?? booking['route']?.toString() ?? 'Unknown Route',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(booking['status']?.toString()).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            (booking['status']?.toString() ?? 'Unknown').toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                              color: _getStatusColor(booking['status']?.toString()),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                                    const SizedBox(height: 8),
                                    // ETA
                            FutureBuilder<String>(
                              future: _calculateETA(booking),
                              builder: (context, etaSnapshot) {
                                String etaText = 'Calculating...';
                                Color etaColor = Colors.orange;
                                IconData etaIcon = Icons.access_time;
                                if (etaSnapshot.hasData) {
                                  etaText = etaSnapshot.data!;
                                  if (etaText == 'Arriving now') {
                                    etaColor = Colors.green;
                                    etaIcon = Icons.near_me;
                                  } else if (etaText.contains('min')) {
                                    etaColor = Colors.blue;
                                    etaIcon = Icons.schedule;
                                          } else if (etaText.contains('Unable') || etaText.contains('N/A')) {
                                    etaColor = Colors.red;
                                    etaIcon = Icons.error_outline;
                                  }
                                }
                                        return Row(
                                    children: [
                                      Icon(etaIcon, size: 16, color: etaColor),
                                      const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                        'ETA: $etaText',
                                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: etaColor),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                        ),
                                      ),
                                    ],
                                );
                              },
                            ),
                                    const SizedBox(height: 8),
                                    // Pickup
                            if (booking['pickupAddress'] != null)
                              Row(
                                children: [
                                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Pickup: ${booking['pickupAddress']}',
                                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                                    const SizedBox(height: 6), // Reduced from 12
                                    // View Details button
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showBookingDetails(context, booking),
                                        icon: const Icon(Icons.visibility, size: 16),
                                        label: const Text('View Details', style: TextStyle(fontSize: 13)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    // Add delete icon button here
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Delete Booking',
                                      onPressed: () => _deleteBooking(booking['id']),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action Buttons Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green[50]!, Colors.white],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PassengerMapScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.event_seat, color: Colors.white),
                        label: const Text('Book a Bus',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          print('[DEBUG] Track Bus button pressed');
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CurrentBusesScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.location_searching,
                            color: Colors.white),
                        label: const Text('Track Bus',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Place the carousel below the main buttons
        const SizedBox(height: 12),
        IndependentImageCarousel(images: _carouselImages),
        const SizedBox(height: 18),
        _buildBookedBusesSection(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
            // Removed _showDropdown logic
          },
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildMainContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isLoadingUser
                    ? const SizedBox(
                        width: 120,
                        height: 20,
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    : Text(
                        '${_getGreeting()}, ${_username ?? 'User'} 👋',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                const SizedBox(height: 4),
                Text(
                  'Where to, Captain? 🚌🧭',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              GestureDetector(
                onTap: _navigateToProfile,
                child: CircleAvatar(
                  backgroundColor: Colors.green[700],
                  child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            _profileImageUrl!,
                            fit: BoxFit.cover,
                            width: 40,
                            height: 40,
                          ),
                        )
                      : Text(
                          _username != null && _username!.isNotEmpty
                              ? _username![0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              if (_hasActiveBooking)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBookingDetails(
      BuildContext context, Map<String, dynamic> booking) async {
    try {
      final busId = booking['busId'];
      final pickupLocation = booking['pickupLocation'];
      BitmapDescriptor? passengerIcon;

      // Validate booking data
      if (booking.isEmpty) {
        throw Exception('Invalid booking data');
      }

      if (pickupLocation != null) {
        try {
          passengerIcon = await MarkerIcons.passengerIcon;
        } catch (e) {
          print('Error loading passenger icon: $e');
          // Continue without icon if it fails to load
        }
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => LiveBusDetailsSheet(
            busId: busId?.toString() ?? '',
            booking: booking,
            passengerIcon: passengerIcon,
          ),
        );
      }
    } catch (e) {
      print('Error showing booking details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading booking details:  {e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Add this method to delete a booking and refresh the list
  Future<void> _deleteBooking(String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Booking'),
        content: const Text('Are you sure you want to delete this booking? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('bookings').doc(bookingId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking deleted successfully'), backgroundColor: Colors.green),
          );
          _loadUserData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting booking: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

// 1. Move the carousel widget to a new StatefulWidget class
class IndependentImageCarousel extends StatefulWidget {
  final List<String> images;
  const IndependentImageCarousel({Key? key, required this.images}) : super(key: key);

  @override
  State<IndependentImageCarousel> createState() => _IndependentImageCarouselState();
}

class _IndependentImageCarouselState extends State<IndependentImageCarousel> {
  int _carouselIndex = 0;
  PageController? _carouselPageController;
  Timer? _carouselTimer;
  final Map<int, Image> _preloadedImages = {};

  @override
  void initState() {
    super.initState();
    _carouselPageController = PageController(initialPage: 0);
    _preloadImages();
    _carouselTimer = Timer.periodic(const Duration(seconds: 2), (timer) { // Reduced from 4 seconds
      if (mounted && _carouselPageController != null) {
        int nextPage = (_carouselIndex + 1) % widget.images.length;
        _carouselPageController!.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400), // Reduced from 800
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _preloadImages() {
    for (int i = 0; i < widget.images.length; i++) {
      _preloadedImages[i] = Image.asset(
        widget.images[i],
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
        cacheWidth: 800,
        cacheHeight: 400,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
            ),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselPageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 200,
        width: MediaQuery.of(context).size.width - 32,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              PageView.builder(
                itemCount: widget.images.length,
                controller: _carouselPageController,
                onPageChanged: (index) {
                  setState(() {
                    _carouselIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    },
                    child: SizedBox(
                      key: ValueKey(index),
                      width: double.infinity,
                      height: 200,
                      child: _preloadedImages[index] ?? Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Gradient overlay for better text visibility
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _carouselIndex == index ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _carouselIndex == index
                            ? Colors.green[700]
                            : Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          if (_carouselIndex == index)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}














