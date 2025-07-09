import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import all the screens
import 'ticket_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'passenger_map_screen.dart';
import 'customer_home_screen.dart';
import 'bus_driver_home_screen.dart';
import 'driver_map_screen.dart';
import 'admin_home_screen.dart';

// Navigation item model
class NavBarItem {
  final IconData icon;
  final String label;
  final Widget screen;

  NavBarItem({required this.icon, required this.label, required this.screen});
}

class NavBarScreen extends StatefulWidget {
  final String userRole;

  const NavBarScreen({super.key, required this.userRole});

  @override
  State<NavBarScreen> createState() => _NavBarScreenState();
}

class _NavBarScreenState extends State<NavBarScreen> {
  int _selectedIndex = 0;
  late List<NavBarItem> _navigationItems;

  @override
  void initState() {
    super.initState();
    _initializeNavigationItems();
  }

  void _initializeNavigationItems() {
    switch (widget.userRole.toLowerCase()) {
      case 'user':
      case 'passenger':
        _navigationItems = _getPassengerNavigationItems();
        break;
      case 'driver':
        _navigationItems = _getDriverNavigationItems();
        break;
      case 'admin':
        _navigationItems = _getAdminNavigationItems();
        break;
      default:
        _navigationItems =
            _getPassengerNavigationItems(); // Default to passenger
    }
  }

  List<NavBarItem> _getPassengerNavigationItems() {
    return [
      NavBarItem(
        icon: Icons.dashboard,
        label: "Dashboard",
        screen: const BusTrackingScreen(),
      ),
      NavBarItem(
        icon: Icons.location_on,
        label: "Map",
        screen: const PassengerMapScreen(),
      ),
      NavBarItem(
        icon: Icons.confirmation_number,
        label: "Tickets",
        screen: const TicketScreen(),
      ),
      NavBarItem(
        icon: Icons.settings,
        label: "Settings",
        screen: const SettingsScreen(),
      ),
      NavBarItem(
        icon: Icons.person,
        label: "Profile",
        screen: const ProfileScreen(),
      ),
    ];
  }

  List<NavBarItem> _getDriverNavigationItems() {
    return [
      NavBarItem(
        icon: Icons.home,
        label: "Home",
        screen: BusDriverHomeScreen(),
      ),
      NavBarItem(
        icon: Icons.map,
        label: "Map",
        screen: const DriverMapScreen(),
      ),
      NavBarItem(
        icon: Icons.settings,
        label: "Settings",
        screen: const SettingsScreen(),
      ),
    
    ];
  }

  List<NavBarItem> _getAdminNavigationItems() {
    return [
      NavBarItem(
        icon: Icons.admin_panel_settings,
        label: "Admin",
        screen: const AdminDashboardScreen(),
      ),
      NavBarItem(
        icon: Icons.settings,
        label: "Settings",
        screen: const SettingsScreen(),
      ),
      NavBarItem(
        icon: Icons.person,
        label: "Profile",
        screen: const ProfileScreen(),
      ),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _navigationItems.map((item) => item.screen).toList(),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _navigationItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildNavItem(
              icon: item.icon,
              index: index,
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
    required String label,
  }) {
    final bool isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow : Colors.white,
          shape: BoxShape.circle,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.yellow.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 3,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.green[800] : Colors.black,
          size: 24,
        ),
      ),
    );
  }
}

// Helper function to get NavBarScreen with appropriate role
class NavBarHelper {
  static Widget getNavBarForUser(String userRole) {
    return NavBarScreen(userRole: userRole);
  }

  static Widget getNavBarForCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Get user role from Firestore
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final role = userData['role']?.toString().toLowerCase() ?? 'user';
            return NavBarScreen(userRole: role);
          }
          return NavBarScreen(userRole: 'user'); // Default fallback
        },
      );
    }
    return NavBarScreen(userRole: 'user'); // Default fallback
  }
}

// Screen classes remain the same
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[100]!, Colors.green[50]!],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home, size: 80, color: Colors.green),
              SizedBox(height: 20),
              Text(
                'Home Screen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Welcome to Smart Bus Mobility Platform',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
