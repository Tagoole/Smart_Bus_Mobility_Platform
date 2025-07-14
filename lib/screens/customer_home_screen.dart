import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:smart_bus_mobility_platform1/screens/passenger_map_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:smart_bus_mobility_platform1/screens/booked_buses_screen.dart';

class BusTrackingScreen extends StatefulWidget {
  const BusTrackingScreen({super.key});

  @override
  _BusTrackingScreenState createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen>
    with TickerProviderStateMixin {
  final int _selectedIndex = 0;
  bool _showActiveJourney = false;
  String? _username;
  bool _isLoadingUser = true;
  bool _showDropdown = false; // Add dropdown state

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

      setState(() {
        _recentBookings = recentBookings;
        _userStats = userStats;
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

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- New Buttons Section ---
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
                              builder: (context) => PassengerMapScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.event_seat, color: Colors.white),
                        label:
                            Text('Book a Bus', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookedBusesScreen(),
                            ),
                          );
                        },
                        icon: Icon(Icons.directions_bus, color: Colors.white),
                        label: Text('Track Bus', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
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
        // --- End New Buttons Section ---
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
              // Header
              _buildHeader(),
              // Content
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
}
