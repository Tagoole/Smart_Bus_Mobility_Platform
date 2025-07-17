import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/screens/admin_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/bus_driver_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/nav_bar_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/login_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/signup_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen2.dart';
import 'package:smart_bus_mobility_platform1/screens/email_verification_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/profile_screen.dart'
    as profile;
import 'package:smart_bus_mobility_platform1/screens/personal_data_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/payment_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/customer_home_screen.dart';
import 'package:smart_bus_mobility_platform1/routes/app_routes.dart';
import 'package:flutter/services.dart';
import 'package:smart_bus_mobility_platform1/screens/driver_map_screen.dart';

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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Bus Mobility',
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.blueGrey,
      ),
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
                        if (userSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          );
                        }
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData =
                              userSnapshot.data!.data() as Map<String, dynamic>;
                          final role =
                              userData['role']?.toString().toLowerCase() ?? '';
                          // Route based on user role
                          switch (role) {
                            case 'admin':
                              return AdminDashboardScreen();
                            case 'driver':
                              return BusDriverHomeScreen();
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
                } else if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: Colors.white),
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
        // REMOVED: '/passengerMap': (context) => PassengerMapScreen(),
        '/login': (context) => SignInScreen(),
        '/payment': (context) => PaymentScreen(),
        '/verifyEmail': (context) => EmailVerificationScreen(),
        '/forgotPassword': (context) => ForgotPasswordScreen(),
        '/admin': (context) => AdminDashboardScreen(),
        '/passenger': (context) => BusTrackingScreen(),
        '/busdriver': (context) => DriverMapScreen(),
      },
    );
  }
}
