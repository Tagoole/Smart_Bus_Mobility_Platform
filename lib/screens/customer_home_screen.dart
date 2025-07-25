import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:smart_bus_mobility_platform1/screens/passenger_map_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/booked_buses_screen.dart'
    as booked;
import 'package:smart_bus_mobility_platform1/screens/current_buses_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/track_bus_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/utils/marker_icon_utils.dart';
import 'package:smart_bus_mobility_platform1/widgets/live_bus_details_sheet.dart';

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
  bool _isLoadingUser = true;
  bool _showDropdown = false;

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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchUsername();
    _loadUserData();

    // Set up automatic refresh every 30 seconds for real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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
            _isLoadingUser = false;
          });
        } else {
          setState(() {
            _username = 'User';
            _isLoadingUser = false;
          });
        }
      } catch (e) {
        print('Error fetching username: $e');
        setState(() {
          _username = 'User';
          _isLoadingUser = false;
        });
      }
    } else {
      setState(() {
        _username = 'User';
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Load recent bookings with error handling
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      List<Map<String, dynamic>> recentBookings = [];
      for (var doc in bookingsSnapshot.docs) {
        final bookingData = Map<String, dynamic>.from(doc.data());
        // Add document ID to booking data for reference
        bookingData['id'] = doc.id;
        recentBookings.add(bookingData);
      }

      // Check for active booking
      final activeBookingSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'confirmed')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      Map<String, dynamic>? activeBooking;
      if (activeBookingSnapshot.docs.isNotEmpty) {
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
      GeoPoint? busLocation;
      GeoPoint? pickupGeoPoint;

      // Try to get bus location from different possible formats
      final currentLocation = busData['currentLocation'];
      if (currentLocation is GeoPoint) {
        busLocation = currentLocation;
      } else if (currentLocation is Map<String, dynamic>) {
        final lat = currentLocation['latitude'];
        final lng = currentLocation['longitude'];
        if (lat != null && lng != null) {
          busLocation = GeoPoint(lat.toDouble(), lng.toDouble());
        }
      }

      // Try to get pickup location from different possible formats
      if (pickupLocation is GeoPoint) {
        pickupGeoPoint = pickupLocation;
      } else if (pickupLocation is Map<String, dynamic>) {
        final lat = pickupLocation['latitude'];
        final lng = pickupLocation['longitude'];
        if (lat != null && lng != null) {
          pickupGeoPoint = GeoPoint(lat.toDouble(), lng.toDouble());
        }
      }

      if (busLocation == null || pickupGeoPoint == null) {
        return 'Location unavailable';
      }

      // Calculate distance using Haversine formula
      double distance = _calculateDistance(
        busLocation.latitude,
        busLocation.longitude,
        pickupGeoPoint.latitude,
        pickupGeoPoint.longitude,
      );

      // Estimate time based on average speed (assuming 30 km/h in city traffic)
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

  void _toggleDropdown() {
    setState(() {
      _showDropdown = !_showDropdown;
    });
  }

  void _navigateToProfile() {
    setState(() {
      _showDropdown = false;
    });
    Navigator.pushNamed(context, '/profile');
  }

  Future<void> _logout() async {
    setState(() {
      _showDropdown = false;
    });

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
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: bookings.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final doc = bookings[index];
                  Map<String, dynamic> booking;

                  try {
                    final data = doc.data();
                    if (data is Map<String, dynamic>) {
                      booking = Map<String, dynamic>.from(data);
                    } else {
                      print(
                          'Invalid booking data format for document ${doc.id}');
                      booking = <String, dynamic>{};
                    }
                  } catch (e) {
                    print(
                        'Error parsing booking data for document ${doc.id}: $e');
                    booking = <String, dynamic>{};
                  }

                  booking['id'] = doc.id; // Add document ID

                  return GestureDetector(
                    onTap: () {
                      _showBookingDetails(context, booking);
                    },
                    child: Container(
                      width: 260,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.directions_bus,
                                    color: Colors.green[700], size: 28),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    booking['destination']?.toString() ??
                                        booking['route']?.toString() ??
                                        'Unknown Route',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ETA Section with real-time calculation
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
                                  } else if (etaText.contains('Unable') ||
                                      etaText.contains('N/A')) {
                                    etaColor = Colors.red;
                                    etaIcon = Icons.error_outline;
                                  }
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: etaColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: etaColor.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(etaIcon, size: 16, color: etaColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ETA: $etaText',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: etaColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 12),

                            if (booking['pickupAddress'] != null)
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Pickup: ${booking['pickupAddress']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 8),

                            // Status indicator
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                        booking['status']?.toString()),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (booking['status']?.toString() ?? 'Unknown')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.visibility,
                                          size: 12, color: Colors.green[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'View',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            if (_showDropdown) {
              setState(() {
                _showDropdown = false;
              });
            }
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
                      ),
                const SizedBox(height: 4),
                Text(
                  'Where to, Captain? 🚌🧭',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Stack(
            children: [
              GestureDetector(
                onTap: _toggleDropdown,
                child: CircleAvatar(
                  backgroundColor: Colors.green[700],
                  child: Text(
                    _username != null && _username!.isNotEmpty
                        ? _username![0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
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
              if (_showDropdown)
                Positioned(
                  top: 50,
                  right: 0,
                  child: Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person, color: Colors.blue),
                          title: const Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: _navigateToProfile,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        Divider(height: 1, color: Colors.grey[200]),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                          ),
                          onTap: _logout,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ],
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
          SnackBar(
            content: Text('Error loading booking details: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}




