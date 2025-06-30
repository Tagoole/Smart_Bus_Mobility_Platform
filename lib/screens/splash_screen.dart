import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.55],
            colors: [
              Color(0xFFFFFFFF), // White at 0%
              Color(0xFFFAC32D), // Yellow at 55%
            ],
          ),
        ),
        child: Center(
          child: Text(
            'Smart Bus Mobility Platform',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}