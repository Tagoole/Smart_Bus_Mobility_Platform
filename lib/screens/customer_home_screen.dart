import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smart_bus_mobility_platform1/utils/utils.dart';

class BusTrackingScreen extends StatefulWidget {
  const BusTrackingScreen({super.key});

  @override
  _BusTrackingScreenState createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _showActiveJourney = false;
  String? _username;
  bool _isLoadingUser = true;
  bool _showDropdown = false; // Add dropdown state

  // Enhanced data for dynamic content
  List<Map<String, dynamic>> _recentBookings = [];
  List<Map<String, dynamic>> _nearbyBuses = [];
  Map<String, dynamic>? _userStats;
  List<String> _favoriteRoutes = [];
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
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadUserData();
      }
    });
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _username = doc.data()!['username'] ?? '';
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _username = '';
          _isLoadingUser = false;
        });
      }
    } else {
      setState(() {
        _username = '';
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Load recent bookings
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      List<Map<String, dynamic>> recentBookings = [];
      for (var doc in bookingsSnapshot.docs) {
        recentBookings.add(doc.data());
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
        activeBooking = activeBookingSnapshot.docs.first.data();
      }

      // Load nearby buses (simulated data for now)
      List<Map<String, dynamic>> nearbyBuses = [
        {
          'id': '1',
          'number': '19',
          'route': 'Kampala → Ntinda',
          'eta': '5 mins',
          'distance': '0.2 km',
        },
        {
          'id': '2',
          'number': '23',
          'route': 'Kampala → Entebbe',
          'eta': '12 mins',
          'distance': '0.8 km',
        },
        {
          'id': '3',
          'number': '15',
          'route': 'Kampala → Jinja',
          'eta': '8 mins',
          'distance': '0.5 km',
        },
      ];

      // Load user statistics
      Map<String, dynamic> userStats = {
        'totalTrips': recentBookings.length,
        'totalSpent': recentBookings.fold(
          0.0,
          (sum, booking) => sum + (booking['totalFare'] ?? 0.0),
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

      // Load favorite routes
      List<String> favoriteRoutes = [
        'Kampala → Ntinda',
        'Kampala → Entebbe',
        'Kampala → Jinja',
      ];

      setState(() {
        _recentBookings = recentBookings;
        _nearbyBuses = nearbyBuses;
        _userStats = userStats;
        _favoriteRoutes = favoriteRoutes;
        _hasActiveBooking = activeBooking != null;
        _activeBooking = activeBooking;
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  String _getGreeting() {
    return 'Hello';
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
    // Navigate to profile page
    Navigator.pushNamed(context, '/profile');
  }

  Future<void> _logout() async {
    setState(() {
      _showDropdown = false;
    });

    // Show confirmation dialog
    bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        // Sign out from Firebase
        await FirebaseAuth.instance.signOut();

        // Navigate to login screen and clear all previous routes
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              // Header
              _buildHeader(),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Quick Stats Cards
                        _buildQuickStats(),
                        SizedBox(height: 16),

                        // Active Journey or Main Content
                        _showActiveJourney
                            ? _buildActiveJourney()
                            : _buildMainContent(),
                        SizedBox(height: 32),
                      ],
                    ),
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
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isLoadingUser
                    ? SizedBox(
                        width: 120,
                        height: 20,
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    : Text(
                        '${_getGreeting()}, ${_username ?? ''} 👋',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                SizedBox(height: 4),
                Text(
                  'Where are we heading today?',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '24°C, Kampala',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // Avatar with dropdown
          Stack(
            children: [
              GestureDetector(
                onTap: _toggleDropdown,
                child: CircleAvatar(
                  backgroundColor: Colors.green[700],
                  child: Text(
                    _username != null && _username!.isNotEmpty
                        ? _username![0].toUpperCase()
                        : '',
                    style: TextStyle(
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
              // Dropdown menu
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
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Profile option
                        ListTile(
                          leading: Icon(Icons.person, color: Colors.blue),
                          title: Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: _navigateToProfile,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        Divider(height: 1, color: Colors.grey[200]),
                        // Logout option
                        ListTile(
                          leading: Icon(Icons.logout, color: Colors.red),
                          title: Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.red,
                            ),
                          ),
                          onTap: _logout,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
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

  Widget _buildQuickStats() {
    if (_userStats == null) return SizedBox.shrink();

    return Container(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard(
            'Monthly Trips',
            '${_userStats!['monthlyTrips']}',
            Icons.directions_bus,
            Colors.blue,
          ),
          _buildStatCard(
            'Total Spent',
            '\$${_userStats!['totalSpent'].toStringAsFixed(0)}',
            Icons.attach_money,
            Colors.green,
          ),
          _buildStatCard(
            'Total Trips',
            '${_userStats!['totalTrips']}',
            Icons.route,
            Colors.orange,
          ),
          _buildStatCard(
            'Favorite',
            _userStats!['favoriteRoute'].split('→').last.trim(),
            Icons.favorite,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 120,
      margin: EdgeInsets.only(right: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.1),
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotifications() {
    return Column(
      children: [
        _buildNotificationItem(
          Icons.warning_amber,
          'Bus #19 on Route 3 is delayed by 8 mins',
          Colors.orange,
        ),
        _buildNotificationItem(
          Icons.info,
          'Route 4 temporarily suspended due to maintenance',
          Colors.blue,
        ),
        if (_hasActiveBooking)
          _buildNotificationItem(
            Icons.check_circle,
            'Your bus is on the way! ETA: 14 minutes',
            Colors.green,
          ),
      ],
    );
  }

  Widget _buildNotificationItem(IconData icon, String text, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          Icon(Icons.close, size: 20, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Bus Tracking
        _buildLiveBusTracking(),

        // Nearby Buses
        _buildNearbyBuses(),

        // Recent Bookings
        if (_recentBookings.isNotEmpty) _buildRecentBookings(),

        // Smart Recommendations
        _buildSmartRecommendations(),

        // Quick Actions
        _buildQuickActions(),

        // Favorite Routes
        _buildFavoriteRoutes(),

        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLiveBusTracking() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green[50]!, Colors.white],
            ),
          ),
          child: Stack(
            children: [
              // Background pattern
              Positioned.fill(child: CustomPaint(painter: BusPatternPainter())),
              // Content
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.directions_bus,
                          size: 24,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Live Bus Tracking',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Spacer(),
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${_nearbyBuses.length} buses near you',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/passengerMap');
                            },
                            icon: Icon(Icons.map, size: 16),
                            label: Text('View Map'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showActiveJourney = true;
                              });
                            },
                            icon: Icon(Icons.track_changes, size: 16),
                            label: Text('Track Bus'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyBuses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.near_me, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Nearby Buses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        Container(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _nearbyBuses.length,
            itemBuilder: (context, index) {
              final bus = _nearbyBuses[index];
              return _buildNearbyBusCard(bus);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyBusCard(Map<String, dynamic> bus) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: Colors.blue, size: 16),
                SizedBox(width: 4),
                Text(
                  'Bus ${bus['number']}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              bus['route'],
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bus['eta'],
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  bus['distance'],
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBookings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
          child: Text(
            'Recent Bookings',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Container(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentBookings.length,
            itemBuilder: (context, index) {
              final booking = _recentBookings[index];
              return _buildRecentBookingCard(booking);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBookingCard(Map<String, dynamic> booking) {
    final bus = booking['bus'] as Map<String, dynamic>?;
    final route =
        '${bus?['startPoint'] ?? 'Unknown'} → ${bus?['destination'] ?? 'Unknown'}';
    final date = booking['createdAt'] as Timestamp?;
    final formattedDate = date != null
        ? '${date.toDate().day}/${date.toDate().month}/${date.toDate().year}'
        : 'Unknown';

    return Card(
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue, size: 16),
                SizedBox(width: 4),
                Text(
                  'Booking',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Confirmed',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              route,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              'Bus: ${bus?['numberPlate'] ?? 'Unknown'}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formattedDate,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
                Text(
                  '\$${(booking['totalFare'] ?? 0.0).toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartRecommendations() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple[50]!, Colors.white],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.purple, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Smart Recommendations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildRecommendationItem(
                'Based on your history',
                'Try Route 19 to Ntinda - 15% less crowded',
                Icons.trending_up,
                Colors.green,
              ),
              SizedBox(height: 8),
              _buildRecommendationItem(
                'Weather Alert',
                'Light rain expected - buses may be delayed',
                Icons.cloud,
                Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickActionButton(
                    Icons.qr_code,
                    'Scan Ticket',
                    Colors.blue,
                    () {},
                  ),
                  _buildQuickActionButton(
                    Icons.support_agent,
                    'Support',
                    Colors.orange,
                    () {},
                  ),
                  _buildQuickActionButton(
                    Icons.settings,
                    'Settings',
                    Colors.grey,
                    () {},
                  ),
                  _buildQuickActionButton(
                    Icons.history,
                    'History',
                    Colors.purple,
                    () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteRoutes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
          child: Text(
            'Favorite Routes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Container(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _favoriteRoutes.length,
            itemBuilder: (context, index) {
              return _buildFavoriteRouteChip(_favoriteRoutes[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteRouteChip(String route) {
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(route),
        avatar: Icon(Icons.favorite, size: 16, color: Colors.red),
        onPressed: () {
          // Navigate to booking with pre-filled route
        },
        backgroundColor: Colors.red[50],
        labelStyle: TextStyle(color: Colors.red[700]),
      ),
    );
  }

  Widget _buildDepartureCard(String bus, String to, String eta) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bus $bus', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('to $to', style: TextStyle(fontSize: 13)),
            SizedBox(height: 8),
            Text(
              eta,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green[50],
            child: Icon(icon, color: Colors.green[700]),
          ),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActiveJourney() {
    return Column(
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          margin: EdgeInsets.only(top: 12, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Active Journey Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Active Journey',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Journey Details
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kampala → Ntinda',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Route 19',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ETA 14 mins',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '3 stops left',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // View Live Map Button
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/passengerMap');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 20),
                SizedBox(width: 8),
                Text(
                  'View Live Map',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
        // Back to main content
        TextButton(
          onPressed: () {
            setState(() {
              _showActiveJourney = false;
            });
          },
          child: Text(
            'Back to Main',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(height: 32),
      ],
    );
  }
}

// Custom painter for bus pattern background
class BusPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    // Draw diagonal lines
    for (int i = 0; i < size.width + size.height; i += 20) {
      canvas.drawLine(Offset(i.toDouble(), 0), Offset(0, i.toDouble()), paint);
    }

    // Draw bus icons
    final busPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final x = (size.width / 4) * (i + 1);
      final y = (size.height / 4) * (i + 1);

      // Draw simple bus shape
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 20, height: 12),
        Radius.circular(2),
      );
      canvas.drawRRect(rect, busPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
