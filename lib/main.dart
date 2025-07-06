import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_bus_mobility_platform1/routes/app_routes.dart';
import 'package:smart_bus_mobility_platform1/screens/login_screen.dart';
//import 'package:smart_bus_mobility_platform1/screens/signup_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/email_verification_screen.dart'; // Add this import
import 'package:smart_bus_mobility_platform1/screens/passenger_map_screen.dart'; // Add this import
import 'package:smart_bus_mobility_platform1/screens/login_screen_new.dart';
import 'package:smart_bus_mobility_platform1/screens/signup_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/payment_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/admin_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/customer_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/bus_driver_home_screen.dart';

import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
      //initialRoute: AppRoutes.mapScreen,
      routes: {
        '/signin': (context) => const SignInScreen(), // Add signin route
        '/forgotpassword': (context) =>
            const ForgotPasswordScreen(), // Forgot password route
        '/emailverification': (context) =>
            const EmailVerificationScreen(), // Email verification route
        '/passengerMap': (context) => PassengerMapScreen(),
        '/login': (context) => SignInScreenNew(),
        '/signup': (context) => SignUpScreen(),
        '/payment': (context) => PaymentScreen(),
        '/verifyEmail': (context) => EmailVerificationScreen(),
        '/forgotPassword': (context) => ForgotPasswordScreen(),
        '/admin': (context) => AdminDashboardScreen(),
        '/passenger': (context) => BusTrackingScreen(),
        '/busdriver': (context) => BusDriverHomeScreen(),
      },
      //initialRoute: AppRoutes.mapScreen,
      //home: PaymentSuccess(), // Set the initial home screen
      //home: SplashScreen(),
      //initialRoute: AppRoutes.mapScreen,
      home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            if (snapshot.hasData) {
              // Return your main/home screen here, for example:
              return PassengerMapScreen(); // <-- Replace with your HomeScreen()
            } else if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
          } else if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          return SignInScreen();
        },
      ),
      //home: Scaffold(
      //  backgroundColor: Colors.blue,
      //),
      //),
    );
  }
}
