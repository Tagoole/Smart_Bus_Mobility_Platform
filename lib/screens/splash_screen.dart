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
        child: Stack(
          children: [
            Positioned(
              top: 32,
              left: 24,
              child: Text(
                'smart',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w700, // Bold
                  fontSize: 66,
                  color: Colors.black,
                  letterSpacing: 1,
                ),
              ),
            ),
            Center(
              child: Text(
                'Mobility Platform',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}