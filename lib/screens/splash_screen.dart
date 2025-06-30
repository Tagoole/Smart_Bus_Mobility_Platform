import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    // Setup animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.bounceOut,
    ));

    // Start animations sequentially
    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(Duration(milliseconds: 300));
    _fadeController.forward();
    
    await Future.delayed(Duration(milliseconds: 600));
    _slideController.forward();
    
    await Future.delayed(Duration(milliseconds: 400));
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.4, 0.7, 1.0],
            colors: [
              Color(0xFFFFFFFF), // White at top
              Color(0xFFFFF8E1), // Light cream
              Color(0xFFFAC32D), // Yellow
              Color(0xFFF57F17), // Deeper yellow/orange at bottom
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            _buildBackgroundDecorations(screenWidth, screenHeight),
            
            // Main content
            _buildMainContent(screenWidth, screenHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecorations(double screenWidth, double screenHeight) {
    return Stack(
      children: [
        // Decorative circles
        Positioned(
          top: screenHeight * 0.1,
          right: -50,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: screenHeight * 0.2,
          left: -30,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.05),
              ),
            ),
          ),
        ),
        // Subtle geometric shapes
        Positioned(
          top: screenHeight * 0.3,
          right: 20,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Transform.rotate(
              angle: 0.785398, // 45 degrees
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(double screenWidth, double screenHeight) {
    return Stack(
      children: [
        // SMART text - top center with fade animation
        Positioned(
          top: screenHeight * 0.15,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Text(
                'SMART',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w800,
                  fontSize: screenWidth * 0.16, // Responsive font size
                  color: Colors.black,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // BUS text - left side with slide animation
        Positioned(
          top: screenHeight * 0.35,
          left: screenWidth * 0.08, // 8% from left edge
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildStrokedText(
              'BUS',
              fontSize: screenWidth * 0.18, // Responsive font size
              fillColor: Color(0xFFD3E601),
              strokeColor: Colors.black,
              strokeWidth: 5,
            ),
          ),
        ),

        // Enhanced subtitle with scale animation
        Positioned(
          bottom: screenHeight * 0.25,
          left: 0,
          right: 0,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              children: [
                Text(
                  'Mobility Platform',
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: screenWidth * 0.065, // Responsive font size
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Color(0xFFD3E601),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Additional tagline
        Positioned(
          bottom: screenHeight * 0.15,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              'Smart Transportation Solutions',
              style: TextStyle(
                fontFamily: 'SF Pro Display',
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w400,
                color: Colors.black54,
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Loading indicator at bottom
        Positioned(
          bottom: screenHeight * 0.08,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color(0xFFD3E601),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrokedText(
    String text, {
    required double fontSize,
    required Color fillColor,
    required Color strokeColor,
    required double strokeWidth,
  }) {
    return Stack(
      children: [
        // Stroke
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            letterSpacing: 2,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        // Fill
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            letterSpacing: 2,
            color: fillColor,
          ),
        ),
      ],
    );
  }
}