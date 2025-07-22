import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:smart_bus_mobility_platform1/screens/current_buses_screen.dart';
import 'package:smart_bus_mobility_platform1/utils/theme_provider.dart';
import 'package:smart_bus_mobility_platform1/utils/notification_service.dart';
import 'package:smart_bus_mobility_platform1/screens/admin_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/nav_bar_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/login_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/signup_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen2.dart';
import 'package:smart_bus_mobility_platform1/screens/email_verification_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/profile_screen.dart' as profile;
import 'package:smart_bus_mobility_platform1/screens/personal_data_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/payment_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/customer_home_screen.dart';
import 'package:smart_bus_mobility_platform1/routes/app_routes.dart';
import 'package:smart_bus_mobility_platform1/screens/track_bus_screen.dart';
import 'package:flutter/services.dart';
// Removed extra space

void main() async {
  // Configure error handling to prevent crashes
  BindingBase.debugZoneErrorsAreFatal = false;
  
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Configure logging to reduce excessive output
  if (kDebugMode) {
    // Only show debug logs in debug mode
    print('App starting in debug mode');
  }
  
  // Initialize Firebase based on platform
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyAr7u8PTywBlRtm98NuqNzxPNF2w77vp9s",
        appId: "1:300946521439:web:127b0355935b896df28aea",
        messagingSenderId: "300946521439",
        projectId: "smart-bus-mobility-3f369",
        storageBucket: "smart-bus-mobility-3f369.firebasestorage.app",
      ),
    );
  } else if (Platform.isAndroid) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyAr7u8PTywBlRtm98NuqNzxPNF2w77vp9s",
        appId: "1:300946521439:android:1699793b44477bfaf28aea",
        messagingSenderId: "300946521439",
        projectId: "smart-bus-mobility-3f369",
        storageBucket: "smart-bus-mobility-3f369.firebasestorage.app",
      ),
    );
  }
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Add global error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      print('Flutter error: ${details.exception}');
      print('Stack trace: ${details.stack}');
    }
    // Don't crash the app, just log the error
  };
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Smart Bus Mobility',
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            routes: {
              ...AppRoutes.getRoutes(), // Spread your existing routes
              '/': (context) => StreamBuilder(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.active) {
                    if (snapshot.hasData) {
                      // User is authenticated, get their role and route accordingly
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(snapshot.data!.uid)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: themeProvider.isDarkMode
                                    ? Colors.white
                                    : Colors.green[700],
                              ),
                            );
                          }
                          if (userSnapshot.hasData && userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                            final role = userData['role']?.toString().toLowerCase() ?? '';
                            // Route based on user role
                            switch (role) {
                              case 'admin':
                                return NavBarScreen(userRole: 'admin');
                              case 'driver':
                                return NavBarScreen(userRole: 'driver');
                              case 'user':
                              default:
                                return NavBarScreen(userRole: role);
                            }
                          } else {
                            // Fallback to signin screen if role fetch fails
                            return SignInScreen();
                          }
                        },
                      );
                    } else if (snapshot.hasError) {
                      return Center(child: Text('${snapshot.error}'));
                    }
                  } else if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: themeProvider.isDarkMode
                            ? Colors.white
                            : Colors.green[700],
                      ),
                    );
                  }
                  return SignInScreen();
                },
              ),
              '/signup': (context) => const SignUpScreen(),
              '/signin': (context) => const SignInScreen(),
              '/forgotpassword': (context) => const ForgotPasswordScreen(),
              '/emailverification': (context) => const EmailVerificationScreen(),
              '/forgotpassword2': (context) => const ForgotPasswordScreen2(),
              '/profilescreen': (context) => const profile.ProfileScreen(),
              '/personaldata': (context) => const PersonalData(),
              '/navbar': (context) => NavBarHelper.getNavBarForCurrentUser(),
              '/login': (context) => SignInScreen(),
              '/payment': (context) => PaymentScreen(),
              '/verifyEmail': (context) => EmailVerificationScreen(),
              '/forgotPassword': (context) => ForgotPasswordScreen(),
              '/admin': (context) => AdminDashboardScreen(),
              '/passenger': (context) => BusTrackingScreen(),
              '/busdriver': (context) => NavBarScreen(userRole: 'driver'),
              '/currentBus': (context) => const CurrentBusesScreen(), // Added const and comma
              '/trackBus': (context) {
                final booking = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
                return TrackBusScreen(booking: booking);
              },
            },
          );
        },
      ),
    );
  }
}

class BookingDetailsScreen extends StatelessWidget {
  const BookingDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve the booking details passed as arguments
    final booking = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route: ${booking['route']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${booking['date']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Time: ${booking['time']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Passenger Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Name: ${booking['passengerName']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${booking['passengerEmail']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Phone: ${booking['passengerPhone']}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Navigate to current buses screen instead
                Navigator.pushNamed(context, '/currentBuses');
              },
              child: const Text('Track Current Buses'),
            ),
          ],
        ),
      ),
    );
  }
}





