/*import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'personal_data_screen.dart';
import 'nav_bar_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final int _selectedIndex = 4; // Profile tab index

  Future<void> _logout() async {
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF004d00),
              const Color(0xFF006400),
              const Color(0xFF808080).withValues(alpha: 0.3),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => _onItemTapped(0), // Go to Home
                      ),
                    ),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: () => _onItemTapped(3), // Go to Settings
                      ),
                    ),
                  ],
                ),
              ),

              // Profile Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Profile Picture
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const PersonalData(),
                                  ),
                                );
                              },
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.green[100],
                                    backgroundImage:
                                        null, // TODO: Add user profile image
                                    child: Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green[700],
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // User Name
                            Text(
                              'John Doe',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // User Email
                            Text(
                              'john.doe@example.com',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Edit Profile Button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 5,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PersonalData(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Profile Options
                      _buildProfileOption(
                        icon: Icons.person,
                        title: 'Personal Information',
                        subtitle: 'Update your personal details',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PersonalData(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildProfileOption(
                        icon: Icons.confirmation_number,
                        title: 'My Tickets',
                        subtitle: 'View your ticket history',
                        onTap: () {
                          _onItemTapped(1); // Go to Tickets
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildProfileOption(
                        icon: Icons.location_on,
                        title: 'My Routes',
                        subtitle: 'View your favorite routes',
                        onTap: () {
                          _onItemTapped(2); // Go to Live Location
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildProfileOption(
                        icon: Icons.payment,
                        title: 'Payment Methods',
                        subtitle: 'Manage your payment options',
                        onTap: () {
                          // TODO: Navigate to payment methods
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildProfileOption(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        subtitle: 'Manage your notification preferences',
                        onTap: () {
                          _onItemTapped(3); // Go to Settings
                        },
                      ),

                      const SizedBox(height: 15),

                      _buildProfileOption(
                        icon: Icons.help,
                        title: 'Help & Support',
                        subtitle: 'Get help and contact support',
                        onTap: () {
                          // TODO: Navigate to help screen
                        },
                      ),

                      const SizedBox(height: 15),

                      // Logout option
                      _buildProfileOption(
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out of your account',
                        onTap: _logout,
                      ),

                      const SizedBox(height: 30),

                      // Stats Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Stats',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.confirmation_number,
                                    value: '24',
                                    label: 'Tickets',
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.directions_bus,
                                    value: '156',
                                    label: 'Rides',
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.star,
                                    value: '4.8',
                                    label: 'Rating',
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100), // Extra space for bottom nav
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Bottom Navigation Bar
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
          children: [
            _buildNavItem(icon: Icons.home, index: 0, label: "Home"),
            _buildNavItem(
              icon: Icons.confirmation_number,
              index: 1,
              label: "Tickets",
            ),
            _buildNavItem(
              icon: Icons.location_on,
              index: 2,
              label: "Live Location",
            ),
            _buildNavItem(icon: Icons.settings, index: 3, label: "Settings"),
            _buildNavItem(icon: Icons.person, index: 4, label: "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.green[700], size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.green[700], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
          ),
        ],
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

  void _onItemTapped(int index) {
    if (index != 4) {
      // If not profile tab, navigate to NavBarScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => NavBarHelper.getNavBarForCurrentUser(),
        ),
      );
    }
    // If profile tab (index 4), stay on current screen
  }
}
*/
