import 'package:flutter/material.dart';
import 'package:smart_bus_mobility_platform1/screens/driver_map_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/admin_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/customer_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/email_verification_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/login_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/payment_screen.dart'
    as passenger;
import 'package:smart_bus_mobility_platform1/screens/profile_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/signup_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/passenger_map_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/splash_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/bus_management_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/nav_bar_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/track_bus_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/current_buses_screen.dart'; // Added missing import

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
  static const String driverNavbarScreen = '/driver_navbar';
  static const String trackBusScreen =
      '/trackBus'; // Fixed typo: was 'truckBusScreen' and had extra space
  static const String currentBusesScreen = '/currentBuses';
  //static const String seatSelectionScreen = '/selectSeat';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      // Add more routes here
      splashScreen: (context) => const SplashScreen(),
      signUpScreen: (context) => const SignUpScreen(), // Added const
      loginScreen: (context) => const SignInScreen(), // Added const
      passengerMapScreen: (context) =>
          const PassengerMapScreen(), // Added const
      paymentScreen: (context) =>
          const passenger.PaymentScreen(), // Added const
      profileScreen: (context) => const ProfileScreen(), // Added const
      //mapScreen: (context) => MapScreen(),
      emailVerificationScreen: (context) =>
          const EmailVerificationScreen(), // Added const
      forgotPasswordScreen: (context) =>
          const ForgotPasswordScreen(), // Added const
      adminScreen: (context) => const AdminDashboardScreen(), // Added const
      passengerHomeScreen: (context) =>
          const BusTrackingScreen(), // Added const
      currentBusesScreen: (context) =>
          const CurrentBusesScreen(), // Added const
      trackBusScreen: (context) {
        // Fixed variable name
        final booking =
            ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return TrackBusScreen(booking: booking);
      },
      busDriverHomeScreen: (context) => const DriverMapScreen(), // Added const
      //coordinatetoAddressScreen: (context) => TransformLatLngToAddress(),
      //mountExampleScreen: (context) => const MountExampleScreen(),
      busManagementScreen: (context) =>
          const BusManagementScreen(), // Added const
      driverMapScreen: (context) => const DriverMapScreen(), // Added const
      driverNavbarScreen: (context) {
        // Get initialTab from arguments if provided
        final args = ModalRoute.of(context)?.settings.arguments;
        final initialTab = args is int ? args : 0;
        return NavBarScreen(userRole: 'driver', initialTab: initialTab);
      },
    };
  }
}










