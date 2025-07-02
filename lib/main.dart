import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:smart_bus_mobility_platform1/routes/app_routes.dart';
import 'package:smart_bus_mobility_platform1/screens/login_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/signup_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/forgot_password_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/email_verification_screen.dart'; // Add this import

//import 'firebase_options.dart';
import 'package:smart_bus_mobility_platform1/screens/map_screen.dart';
import 'package:smart_bus_mobility_platform1/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   
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
    return SafeArea(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Smart Bus Mobility',
        theme: ThemeData.light().copyWith(
          scaffoldBackgroundColor: Colors.blueGrey,
        ),
        routes: AppRoutes.getRoutes(), // Spread your existing routes
        //initialRoute: AppRoutes.mapScreen,
        home:SignInScreen(),
                 
        //home: Scaffold(
        //  backgroundColor: Colors.blue,
        //  body: Container(width: 200, height: 200, color: Colors.amberAccent),
        //),
      ),
    );
  }
}