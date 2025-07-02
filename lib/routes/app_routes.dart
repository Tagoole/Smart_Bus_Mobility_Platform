import 'package:flutter/material.dart';
import 'package:smart_bus_mobility_platform1/screens/email_verification_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/login_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/signup_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/map_screen.dart';

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
  static const String emailVerificationScreen = '/verifyEmail';
  static const String forgotPasswordScreen = '/forgotPassword';


  static Map<String, WidgetBuilder> getRoutes() {
    return {
      // Add more routes here
      homeScreen: (context) => SplashScreen(),
      signUpScreen: (context) => SignUpScreen(),
      loginScreen: (context) => SignInScreen(),
      mapScreen: (context) => MapScreen(),
      emailVerificationScreen: (context) => EmailVerificationScreen(),
      forgotPasswordScreen: (context) => ForgotPasswordScreen(),



    };
  }
}
