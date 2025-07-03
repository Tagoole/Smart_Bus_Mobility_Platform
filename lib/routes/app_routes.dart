import 'package:flutter/material.dart';
import 'package:smart_bus_mobility_platform1/screens/admin_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/bus_driver_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/customer_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/email_verification_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/login_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/signup_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/passenger_map_screen.dart';

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
  static const String passengerHomeScreen = '/passenger';
  static const String adminScreen = '/admin';
  static const String busDriverHomeScreen = '/busdriver';
  static const String emailVerificationScreen = '/verifyEmail';
  static const String forgotPasswordScreen = '/forgotPassword';


  static Map<String, WidgetBuilder> getRoutes() {
    return {
      // Add more routes here
      //homeScreen: (context) => SplashScreen(),
      signUpScreen: (context) => SignUpScreen(),
      loginScreen: (context) => SignInScreen(),
      //mapScreen: (context) => MapScreen(),
      emailVerificationScreen: (context) => EmailVerificationScreen(),
      forgotPasswordScreen: (context) => ForgotPasswordScreen(),
      adminScreen: (context) => AdminHomeScreen(),
      passengerHomeScreen: (context) => CustomerHomeScreen(),
      busDriverHomeScreen: (context) => BusDriverHomeScreen()




    };
  }
}
