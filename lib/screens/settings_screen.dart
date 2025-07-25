import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/utils/theme_provider.dart';
import 'package:smart_bus_mobility_platform1/utils/notification_service.dart';
import 'nav_bar_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool locationEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor:
            isDarkMode ? const Color(0xFF1F1F1F) : Colors.green[700],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            // Try to get the user role from Firestore
            final user = FirebaseAuth.instance.currentUser;
            String? role;
            if (user != null) {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              role = doc.data()?['role']?.toString().toLowerCase();
            }
            if (role == 'driver') {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        NavBarScreen(userRole: 'driver', initialTab: 0)),
                (route) => false,
              );
            } else if (role == 'admin') {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        NavBarScreen(userRole: 'admin', initialTab: 0)),
                (route) => false,
              );
            } else {
              // Default: go to customer home
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        NavBarScreen(userRole: 'user', initialTab: 0)),
                (route) => false,
              );
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // General Section
            _buildSectionHeader('GENERAL', isDarkMode),
            _buildSection([
              _buildListTile(
                title: 'Language',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'English',
                      style: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[600],
                          fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                    ),
                  ],
                ),
                onTap: () => _showLanguageDialog(),
                isDarkMode: isDarkMode,
              ),
              _buildDivider(isDarkMode),
              _buildListTile(
                title: 'Notification Settings',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                ),
                onTap: () => _navigateToNotifications(),
                isDarkMode: isDarkMode,
              ),
              _buildDivider(isDarkMode),
              _buildListTile(
                title: 'Location',
                trailing: Switch(
                  value: locationEnabled,
                  activeColor: Colors.green[700],
                  onChanged: (value) {
                    setState(() {
                      locationEnabled = value;
                    });
                  },
                ),
                onTap: null,
                isDarkMode: isDarkMode,
              ),
              _buildListTile(
                title: 'Dark Mode',
                trailing: Switch(
                  value: isDarkMode,
                  activeColor: Colors.green[700],
                  onChanged: (value) async {
                    await themeProvider.setDarkMode(value);
                  },
                ),
                onTap: null,
                isDarkMode: isDarkMode,
              ),
            ], isDarkMode),

            const SizedBox(height: 30),

            // Account & Security Section
            _buildSectionHeader('ACCOUNT & SECURITY', isDarkMode),
            _buildSection([
              _buildListTile(
                title: 'Email and Contact',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                ),
                onTap: () => _navigateToAccountInfo(),
                isDarkMode: isDarkMode,
              ),
              _buildDivider(isDarkMode),
              _buildListTile(
                title: 'Security Settings',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                ),
                onTap: () => _navigateToSecurity(),
                isDarkMode: isDarkMode,
              ),
              _buildDivider(isDarkMode),
              _buildListTile(
                title: 'Delete Account',
                titleColor: Colors.red,
                leading: const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                ),
                onTap: () => _showDeleteAccountDialog(),
                isDarkMode: isDarkMode,
              ),
            ], isDarkMode),

            const SizedBox(height: 30),

            // Other Section
            _buildSectionHeader('OTHER', isDarkMode),
            _buildSection([
              _buildListTile(
                title: 'Smart Bus Mobility',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                ),
                onTap: () => _navigateToAbout(),
                isDarkMode: isDarkMode,
              ),
              _buildDivider(isDarkMode),
              _buildListTile(
                title: 'Privacy Policy',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                ),
                onTap: () => _navigateToPrivacyPolicy(),
                isDarkMode: isDarkMode,
              ),
              _buildDivider(isDarkMode),
              _buildListTile(
                title: 'Terms and Conditions',
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                ),
                onTap: () => _navigateToTerms(),
                isDarkMode: isDarkMode,
              ),
              _buildDivider(isDarkMode),
              _buildListTile(
                title: 'Rate Driver',
                leading: const Icon(
                  Icons.star_outline,
                  color: Colors.green,
                  size: 20,
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                ),
                onTap: () => _rateDriver(),
                isDarkMode: isDarkMode,
              ),
            ], isDarkMode),

            const SizedBox(height: 50),

            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(right: 20, bottom: 20),
              child: Text(
                'v4.87.2',
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: isDarkMode ? Colors.grey[900] : const Color(0xFFF5F5F5),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> children, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required String title,
    Widget? leading,
    Widget? trailing,
    Color? titleColor,
    VoidCallback? onTap,
    bool isDarkMode = false,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: titleColor ?? (isDarkMode ? Colors.white : Colors.black87),
        ),
      ),
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      minLeadingWidth: 20,
    );
  }

  Widget _buildDivider(bool isDarkMode) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
      indent: 20,
      endIndent: 0,
    );
  }

  // Navigation and Action Methods
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Vietnamese'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('French'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _navigateToNotifications() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) {
        bool pushNotifications = themeProvider.notificationsEnabled;
        bool emailNotifications = themeProvider.emailNotificationsEnabled;
        bool smsNotifications = themeProvider.smsNotificationsEnabled;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor:
                isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
            title: Text(
              'Notification Preferences',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(
                    'Push Notifications',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Receive notifications about bookings and bus updates',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                  value: pushNotifications,
                  onChanged: (val) => setState(() => pushNotifications = val),
                ),
                SwitchListTile(
                  title: Text(
                    'Email Notifications',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Receive booking confirmations via email',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                  value: emailNotifications,
                  onChanged: (val) => setState(() => emailNotifications = val),
                ),
                SwitchListTile(
                  title: Text(
                    'SMS Notifications',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Receive booking confirmations via SMS',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                  value: smsNotifications,
                  onChanged: (val) => setState(() => smsNotifications = val),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.green[700],
                  ),
                ),
                onPressed: () async {
                  await themeProvider.updateNotificationSettings(
                    notifications: pushNotifications,
                    emailNotifications: emailNotifications,
                    smsNotifications: smsNotifications,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Notification preferences saved.'),
                      backgroundColor:
                          isDarkMode ? Colors.grey[700] : Colors.green[700],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToAccountInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    // Fetch user data from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User data not found')),
      );
      return;
    }

    final userData = doc.data()!;
    final emailController =
        TextEditingController(text: userData['email'] ?? '');
    final contactController =
        TextEditingController(text: userData['contact'] ?? '');

    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
        title: Text(
          'Account Information',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                ),
              ),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: false, // Make email read-only
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contactController,
              decoration: InputDecoration(
                labelText: 'Contact',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                ),
              ),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              keyboardType: TextInputType.phone,
              enabled: false, // Make contact read-only
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _navigateToSecurity() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Security Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(labelText: 'Current Password'),
              obscureText: true,
            ),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () {
              // Save logic here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete Account',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone and will permanently remove all your data including bookings, notifications, and settings.',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteUserAccount();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUserAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor:
              Provider.of<ThemeProvider>(context, listen: false).isDarkMode
                  ? const Color(0xFF2D2D2D)
                  : Colors.white,
          content: Row(
            children: [
              CircularProgressIndicator(
                color: Provider.of<ThemeProvider>(context, listen: false)
                        .isDarkMode
                    ? Colors.white
                    : Colors.green,
              ),
              const SizedBox(width: 16),
              Text(
                'Deleting account...',
                style: TextStyle(
                  color: Provider.of<ThemeProvider>(context, listen: false)
                          .isDarkMode
                      ? Colors.white
                      : Colors.black,
                ),
              ),
            ],
          ),
        ),
      );

      // Delete user data from Firestore
      final batch = FirebaseFirestore.instance.batch();

      // Delete user document
      batch
          .delete(FirebaseFirestore.instance.collection('users').doc(user.uid));

      // Delete user's bookings
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in bookingsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete user's notifications
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .get();

      for (var doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete pickup locations
      final pickupLocationsSnapshot = await FirebaseFirestore.instance
          .collection('pickup_locations')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in pickupLocationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit all deletions
      await batch.commit();

      // Delete the Firebase Auth user
      await user.delete();

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Navigate to login screen and clear all routes
      if (mounted) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Smart Bus Mobility'),
        content: const Text(
          'Smart Bus Mobility is a platform to make your bus journeys easier, safer, and smarter. Version 4.87.2.',
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _navigateToPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'We value your privacy. Your data is protected and will not be shared without your consent.',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _navigateToTerms() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and Conditions'),
        content: const SingleChildScrollView(
          child: Text(
            'By using Smart Bus Mobility, you agree to our terms and conditions.',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _rateDriver() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to rate drivers')),
      );
      return;
    }

    // Get user's recent bookings to find drivers they can rate
    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    if (bookingsSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No completed trips found. Rate drivers after completing a trip.'),
        ),
      );
      return;
    }

    // Get unique drivers from bookings
    final drivers = <String, Map<String, dynamic>>{};
    for (var doc in bookingsSnapshot.docs) {
      final booking = doc.data();
      final busId = booking['busId'];
      if (busId != null) {
        final busDoc = await FirebaseFirestore.instance
            .collection('buses')
            .doc(busId)
            .get();
        if (busDoc.exists) {
          final busData = busDoc.data()!;
          final driverId = busData['driverId'];
          final driverName = busData['driverName'] ?? 'Unknown Driver';
          final busPlate = busData['numberPlate'] ?? 'Unknown Bus';

          if (driverId != null && !drivers.containsKey(driverId)) {
            drivers[driverId] = {
              'driverId': driverId,
              'driverName': driverName,
              'busPlate': busPlate,
              'bookingId': doc.id,
              'destination': booking['destination'] ?? 'Unknown',
              'date': booking['createdAt'],
            };
          }
        }
      }
    }

    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No drivers found to rate.'),
        ),
      );
      return;
    }

    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
        title: Text(
          'Rate Your Driver',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers.values.elementAt(index);
              return Card(
                color: isDarkMode ? const Color(0xFF3D3D3D) : Colors.grey[50],
                child: ListTile(
                  title: Text(
                    driver['driverName'],
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bus: ${driver['busPlate']}',
                        style: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                      Text(
                        'To: ${driver['destination']}',
                        style: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.star, color: Colors.amber),
                    onPressed: () => _showRatingDialog(driver),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Close',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
              ),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(Map<String, dynamic> driver) {
    final isDarkMode =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    double rating = 5.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
          title: Text(
            'Rate ${driver['driverName']}',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Star Rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        rating = index + 1.0;
                      });
                    },
                    child: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text(
                '${rating.toInt()}/5 Stars',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                decoration: InputDecoration(
                  labelText: 'Comment (optional)',
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Rating'),
              onPressed: () async {
                await _submitDriverRating(
                  driver['driverId'],
                  driver['driverName'],
                  rating,
                  commentController.text,
                  driver['bookingId'],
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitDriverRating(
    String driverId,
    String driverName,
    double rating,
    String comment,
    String bookingId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Save rating to Firestore
      await FirebaseFirestore.instance.collection('driver_ratings').add({
        'driverId': driverId,
        'driverName': driverName,
        'userId': user.uid,
        'userEmail': user.email,
        'rating': rating,
        'comment': comment,
        'bookingId': bookingId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update driver's average rating
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('driver_ratings')
          .where('driverId', isEqualTo: driverId)
          .get();

      double totalRating = 0;
      int ratingCount = 0;

      for (var doc in ratingsSnapshot.docs) {
        totalRating += doc.data()['rating'] ?? 0;
        ratingCount++;
      }

      final averageRating = ratingCount > 0 ? totalRating / ratingCount : 0;

      // Update driver document with new average rating
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'averageRating': averageRating,
        'ratingCount': ratingCount,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you for rating $driverName!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Close the driver list dialog
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}


