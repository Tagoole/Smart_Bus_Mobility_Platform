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
import 'package:smart_bus_mobility_platform1/screens/bus_driver_home_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/track_bus_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/splash_screen.dart';
import 'package:flutter/services.dart';

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
      options: const FirebaseOptions(
        apiKey: "AIzaSyAr7u8PTywBlRtm98NuqNzxPNF2w77vp9s",
        appId: "1:300946521439:web:127b0355935b896df28aea",
        messagingSenderId: "300946521439",
        projectId: "smart-bus-mobility-3f369",
        storageBucket: "smart-bus-mobility-3f369.firebasestorage.app",
      ),
    );
  } else if (Platform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
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
  
  runApp(const MyApp());
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
            initialRoute: '/', // Set splash screen as initial route
            routes: AppRoutes.getRoutes(), // Use the routes from AppRoutes
          );
        },
      ),
    );
  }
}









