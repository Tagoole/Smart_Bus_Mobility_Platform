import 'package:flutter/material.dart';

class AppRoutes {
  static const String mapScreen = '/map';
  static const String homeScreen = '/home';
  static const String loginScreen = '/login';
  static const String paymentScreen = '/payment';
  static const String profileScreen = '/profile';
  static const String settingsScreen = '/settings';
  static const String signUpScreen = '/signup';
  static const String ticketScreen = '/ticket';
  static const String seatBookingScreen = '/seatbooking';
  static const String passengerScreen = '/passenger';
  static const String adminScreen = '/admin';
  static const String busDriverScreen = '/busdriver';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      // Add more routes here
      // homeScreen: (context) => HomeScreen(),
    };
  }
}
