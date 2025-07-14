import 'package:flutter/material.dart';
import 'package:smart_bus_mobility_platform1/screens/driver_map_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/admin_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/customer_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/email_verification_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/login_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/payment_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/profile_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/signup_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/passenger_map_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/splash_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/bus_management_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/nav_bar_screen.dart';

class AppRoutes {
  static const String splashScreen = '/';
  static const String passengerMapScreen = '/passengerMap';
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
  static const String busDriverScreen = '/busdriver';
  static const String availableBusScreen = '/availablebus';
  static const String selectSeatScreen = '/selectseat';
  static const String busDriverHomeScreen = '/busdriver';
  static const String emailVerificationScreen = '/verifyEmail';
  static const String forgotPasswordScreen = '/forgotPassword';
  static const String coordinatetoAddressScreen = '/coordinateToAddress';
  static const String mountExampleScreen = '/mount-example';
  static const String busManagementScreen = '/busManagement';
  static const String driverMapScreen = '/driverMap';
  //static const String seatSelectionScreen = '/selectSeat';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      // Add more routes here
      splashScreen: (context) => const SplashScreen(),
      signUpScreen: (context) => SignUpScreen(),
      loginScreen: (context) => SignInScreen(),
      passengerMapScreen: (context) => PassengerMapScreen(),
      paymentScreen: (context) => PaymentScreen(),
      profileScreen: (context) => ProfileScreen(),
      //mapScreen: (context) => MapScreen(),
      emailVerificationScreen: (context) => EmailVerificationScreen(),
      forgotPasswordScreen: (context) => ForgotPasswordScreen(),
      adminScreen: (context) => AdminDashboardScreen(),
      passengerHomeScreen: (context) => BusTrackingScreen(),

      busDriverHomeScreen: (context) => NavBarScreen(userRole: 'driver'),
      //coordinatetoAddressScreen: (context) => TransformLatLngToAddress(),
      //mountExampleScreen: (context) => const MountExampleScreen(),
      busManagementScreen: (context) => BusManagementScreen(),
      driverMapScreen: (context) => DriverMapScreen(),
    };
  }
}


