





import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoRefreshEnabled = true;
  String _selectedLanguage = 'English';
  String _selectedCurrency = 'USD';
  late SharedPreferences _prefs;
  bool _isLoading = true;

  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Arabic',
  ];

  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
      _locationEnabled = _prefs.getBool('location_enabled') ?? true;
      _darkModeEnabled = _prefs.getBool('dark_mode_enabled') ?? false;
      _autoRefreshEnabled = _prefs.getBool('auto_refresh_enabled') ?? true;
      _selectedLanguage = _prefs.getString('selected_language') ?? 'English';
      _selectedCurrency = _prefs.getString('selected_currency') ?? 'USD';
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    await _prefs.setBool(key, value);
  }

  Future<void> _saveStringSetting(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.green[700]!,
                Colors.green[100]!,
                Colors.green[50]!,
              ],
              stops: const [0.0, 0.3, 1.0],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  'Loading settings...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[700]!, Colors.green[100]!, Colors.green[50]!],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.settings,
                          color: Colors.green[700],
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'App Settings',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Customize your app experience',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Notifications Section
                _buildSectionTitle('Notifications'),
                _buildSwitchTile(
                  icon: Icons.notifications,
                  title: 'Push Notifications',
                  subtitle: 'Receive alerts for bus updates',
                  value: _notificationsEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    await _saveSetting('notifications_enabled', value);
                    _showSuccessMessage(
                      'Notifications ${value ? 'enabled' : 'disabled'}',
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Location Section
                _buildSectionTitle('Location'),
                _buildSwitchTile(
                  icon: Icons.location_on,
                  title: 'Location Services',
                  subtitle: 'Allow app to access your location',
                  value: _locationEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _locationEnabled = value;
                    });
                    await _saveSetting('location_enabled', value);
                    _showSuccessMessage(
                      'Location services ${value ? 'enabled' : 'disabled'}',
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Appearance Section
                _buildSectionTitle('Appearance'),
                _buildSwitchTile(
                  icon: Icons.dark_mode,
                  title: 'Dark Mode',
                  subtitle: 'Use dark theme',
                  value: _darkModeEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _darkModeEnabled = value;
                    });
                    await _saveSetting('dark_mode_enabled', value);
                    _showSuccessMessage(
                      'Dark mode ${value ? 'enabled' : 'disabled'}',
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Data & Storage Section
                _buildSectionTitle('Data & Storage'),
                _buildSwitchTile(
                  icon: Icons.refresh,
                  title: 'Auto Refresh',
                  subtitle: 'Automatically update bus locations',
                  value: _autoRefreshEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _autoRefreshEnabled = value;
                    });
                    await _saveSetting('auto_refresh_enabled', value);
                    _showSuccessMessage(
                      'Auto refresh ${value ? 'enabled' : 'disabled'}',
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Language Selection
                _buildSectionTitle('Language'),
                _buildSelectionTile(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: 'Choose your preferred language',
                  selectedValue: _selectedLanguage,
                  options: _languages,
                  onChanged: (value) async {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                    await _saveStringSetting('selected_language', value!);
                    _showSuccessMessage('Language changed to $value');
                  },
                ),

                const SizedBox(height: 20),

                // Currency Selection
                _buildSectionTitle('Currency'),
                _buildSelectionTile(
                  icon: Icons.attach_money,
                  title: 'Currency',
                  subtitle: 'Select your preferred currency',
                  selectedValue: _selectedCurrency,
                  options: _currencies,
                  onChanged: (value) async {
                    setState(() {
                      _selectedCurrency = value!;
                    });
                    await _saveStringSetting('selected_currency', value!);
                    _showSuccessMessage('Currency changed to $value');
                  },
                ),

                const SizedBox(height: 30),

                // Account Section
                _buildSectionTitle('Account'),
                _buildActionTile(
                  icon: Icons.person,
                  title: 'Profile Settings',
                  subtitle: 'Manage your account information',
                  onTap: () {
                    // TODO: Navigate to profile settings
                  },
                ),

                const SizedBox(height: 15),

                _buildActionTile(
                  icon: Icons.security,
                  title: 'Privacy & Security',
                  subtitle: 'Manage your privacy settings',
                  onTap: () {
                    // TODO: Navigate to privacy settings
                  },
                ),

                const SizedBox(height: 15),

                _buildActionTile(
                  icon: Icons.help,
                  title: 'Help & Support',
                  subtitle: 'Get help and contact support',
                  onTap: () {
                    // TODO: Navigate to help screen
                  },
                ),

                const SizedBox(height: 15),

                _buildActionTile(
                  icon: Icons.info,
                  title: 'About',
                  subtitle: 'App version and information',
                  onTap: () {
                    _showAboutDialog();
                  },
                ),

                const SizedBox(height: 30),

                // Data Management Section
                _buildSectionTitle('Data Management'),
                _buildActionTile(
                  icon: Icons.delete,
                  title: 'Clear Cache',
                  subtitle: 'Free up storage space',
                  onTap: () {
                    _showClearCacheDialog();
                  },
                ),

                const SizedBox(height: 15),

                _buildActionTile(
                  icon: Icons.logout,
                  title: 'Sign Out',
                  subtitle: 'Sign out of your account',
                  onTap: () {
                    _showSignOutDialog();
                  },
                ),

                const SizedBox(height: 30),

                // App Version
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Smart Bus Mobility Platform',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Version 1.0.0',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '© 2024 Smart Bus. All rights reserved.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(10),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green[700],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String selectedValue,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
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
            ],
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: selectedValue,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.green[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.green[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.green[700]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.green[50],
            ),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(10),
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

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green[700], size: 30),
              const SizedBox(width: 10),
              const Text('About'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Bus Mobility Platform',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 10),
              const Text('Version: 1.0.0'),
              const Text('Build: 2024.1.0'),
              const SizedBox(height: 10),
              const Text(
                'A comprehensive bus transportation app that helps users navigate, purchase tickets, and track buses in real-time.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: Colors.green[700])),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showClearCacheDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.orange[700], size: 30),
              const SizedBox(width: 10),
              const Text('Clear Cache'),
            ],
          ),
          content: const Text(
            'This will clear all cached data including offline maps and temporary files. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _clearCache();
              },
              child: Text('Clear', style: TextStyle(color: Colors.orange[700])),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearCache() async {
    try {
      // Clear app cache directory
      final cacheDir = await getTemporaryDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      // Clear app documents directory (for offline maps)
      final appDir = await getApplicationDocumentsDirectory();
      final mapsDir = Directory('${appDir.path}/maps');
      if (await mapsDir.exists()) {
        await mapsDir.delete(recursive: true);
      }

      _showSuccessMessage('Cache cleared successfully!');
    } catch (e) {
      _showErrorMessage('Failed to clear cache: $e');
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[700], size: 30),
              const SizedBox(width: 10),
              const Text('Sign Out'),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out? You will need to sign in again to access your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implement sign out functionality
                _showSuccessMessage('Signed out successfully!');
              },
              child: Text('Sign Out', style: TextStyle(color: Colors.red[700])),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
