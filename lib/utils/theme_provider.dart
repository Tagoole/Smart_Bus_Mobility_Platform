import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';
  static const String _notificationKey = 'notifications_enabled';
  static const String _emailNotificationKey = 'email_notifications_enabled';
  static const String _smsNotificationKey = 'sms_notifications_enabled';

  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  bool _smsNotificationsEnabled = false;

  bool get isDarkMode => _isDarkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get emailNotificationsEnabled => _emailNotificationsEnabled;
  bool get smsNotificationsEnabled => _smsNotificationsEnabled;

  ThemeProvider() {
    _loadThemeFromPrefs();
    _loadNotificationSettings();
  }

  // Load theme from SharedPreferences
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  // Load notification settings from SharedPreferences
  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_notificationKey) ?? true;
    _emailNotificationsEnabled = prefs.getBool(_emailNotificationKey) ?? false;
    _smsNotificationsEnabled = prefs.getBool(_smsNotificationKey) ?? false;
    notifyListeners();
  }

  // Toggle dark mode
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemeToPrefs();
    await _saveThemeToFirebase();
    notifyListeners();
  }

  // Set dark mode
  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    await _saveThemeToPrefs();
    await _saveThemeToFirebase();
    notifyListeners();
  }

  // Save theme to SharedPreferences
  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
  }

  // Save theme to Firebase
  Future<void> _saveThemeToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'isDarkMode': _isDarkMode,
          'lastThemeUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving theme to Firebase: $e');
    }
  }

  // Update notification settings
  Future<void> updateNotificationSettings({
    bool? notifications,
    bool? emailNotifications,
    bool? smsNotifications,
  }) async {
    if (notifications != null) _notificationsEnabled = notifications;
    if (emailNotifications != null)
      _emailNotificationsEnabled = emailNotifications;
    if (smsNotifications != null) _smsNotificationsEnabled = smsNotifications;

    await _saveNotificationSettings();
    await _saveNotificationSettingsToFirebase();
    notifyListeners();
  }

  // Save notification settings to SharedPreferences
  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationKey, _notificationsEnabled);
    await prefs.setBool(_emailNotificationKey, _emailNotificationsEnabled);
    await prefs.setBool(_smsNotificationKey, _smsNotificationsEnabled);
  }

  // Save notification settings to Firebase
  Future<void> _saveNotificationSettingsToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'notificationSettings': {
            'pushNotifications': _notificationsEnabled,
            'emailNotifications': _emailNotificationsEnabled,
            'smsNotifications': _smsNotificationsEnabled,
          },
          'lastNotificationUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving notification settings to Firebase: $e');
    }
  }

  // Load settings from Firebase
  Future<void> loadSettingsFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;

          // Load theme
          if (data.containsKey('isDarkMode')) {
            _isDarkMode = data['isDarkMode'] ?? false;
            await _saveThemeToPrefs();
          }

          // Load notification settings
          if (data.containsKey('notificationSettings')) {
            final notificationSettings =
                data['notificationSettings'] as Map<String, dynamic>?;
            if (notificationSettings != null) {
              _notificationsEnabled =
                  notificationSettings['pushNotifications'] ?? true;
              _emailNotificationsEnabled =
                  notificationSettings['emailNotifications'] ?? false;
              _smsNotificationsEnabled =
                  notificationSettings['smsNotifications'] ?? false;
              await _saveNotificationSettings();
            }
          }

          notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading settings from Firebase: $e');
    }
  }

  // Get theme data
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.green,
      primaryColor: const Color(0xFF004d00),
      scaffoldBackgroundColor: Colors.grey[100],
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF004d00),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF004d00),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.green,
      primaryColor: const Color(0xFF00FF00),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F1F1F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2D2D2D),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF00),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
      ),
    );
  }
}
 



