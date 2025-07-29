import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});


  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotateController;
  late AnimationController _busController;

  // Controllers for individual bus animations
  late AnimationController _bus1Controller;
  late AnimationController _bus2Controller;
  late AnimationController _bus3Controller;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _busAnimation;

  // Individual bus animations
  late Animation<double> _bus1Scale;
  late Animation<double> _bus2Scale;
  late Animation<double> _bus3Scale;

  // Track which bus is currently selected
  int _selectedBus = -1;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
    _startAnimations();
  }

  void _initializeControllers() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800), // Reduced from 2000
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600), // Reduced from 1500
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500), // Reduced from 1000
      vsync: this,
    );

    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 1000), // Reduced from 2500
      vsync: this,
    );

    _busController = AnimationController(
      duration: const Duration(milliseconds: 800), // Reduced from 2000
      vsync: this,
    );

    // Individual bus controllers
    _bus1Controller = AnimationController(
      duration: const Duration(milliseconds: 200), // Reduced from 300
      vsync: this,
    );

    _bus2Controller = AnimationController(
      duration: const Duration(milliseconds: 200), // Reduced from 300
      vsync: this,
    );

    _bus3Controller = AnimationController(
      duration: const Duration(milliseconds: 200), // Reduced from 300
      vsync: this,
    );
  }

  void _setupAnimations() {
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1.5, 0.0), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.bounceOut),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    _busAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _busController, curve: Curves.easeOutBack),
    );

    // Individual bus scale animations
    _bus1Scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bus1Controller, curve: Curves.elasticOut),
    );

    _bus2Scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bus2Controller, curve: Curves.elasticOut),
    );

    _bus3Scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _bus3Controller, curve: Curves.elasticOut),
    );
  }

  void _startAnimations() async {
    // Start all animations almost simultaneously for faster loading
    await Future.delayed(const Duration(milliseconds: 100)); // Reduced from 300
    if (mounted) {
      _fadeController.forward();
      _slideController.forward();
    }

    await Future.delayed(const Duration(milliseconds: 200)); // Reduced from 400
    if (mounted) _scaleController.forward();

    await Future.delayed(const Duration(milliseconds: 100)); // Reduced from 600
    if (mounted) _rotateController.forward();

    await Future.delayed(const Duration(milliseconds: 200)); // Reduced from 500
    if (mounted) _busController.forward();

    // Display splash screen for 15 seconds
    await Future.delayed(const Duration(milliseconds: 15000)); // Changed to 15 seconds
    if (mounted) {
      _navigateToAppropriateScreen();
    }
  }

  void _navigateToAppropriateScreen() async {
    try {
      // Add timeout to prevent hanging
      final timeout = Future.delayed(const Duration(milliseconds: 3000));
      
      // Check if user is already logged in
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // User is logged in, get user role from Firestore with timeout
        final userDocFuture = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        // Race between timeout and Firestore call
        final userDoc = await Future.any([userDocFuture, timeout.then((_) => null)]);

        if (mounted) {
          if (userDoc != null && userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            final role = userData['role']?.toString().toLowerCase() ?? '';

            switch (role) {
              case 'admin':
                Navigator.pushReplacementNamed(context, '/admin');
                break;
              case 'driver':
                Navigator.pushReplacementNamed(
                  context,
                  '/busdriver',
                );
                break;
              case 'user':
              default:
                Navigator.pushReplacementNamed(
                  context,
                  '/passenger',
                );
                break;
            }
          } else {
            // Fallback to passenger screen if role fetch fails or times out
            Navigator.pushReplacementNamed(
              context,
              '/passenger',
            );
          }
        }
      } else {
        // User is not logged in, navigate to login screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.loginScreen);
        }
      }
    } catch (e) {
      // Handle any errors gracefully
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.loginScreen);
      }
    }
  }

  void _onBusPressed(int busIndex) {
    setState(() {
      _selectedBus = busIndex;
    });

    // Animate the selected bus
    switch (busIndex) {
      case 0:
        _bus1Controller.forward();
        _bus2Controller.reverse();
        _bus3Controller.reverse();
        break;
      case 1:
        _bus1Controller.reverse();
        _bus2Controller.forward();
        _bus3Controller.reverse();
        break;
      case 2:
        _bus1Controller.reverse();
        _bus2Controller.reverse();
        _bus3Controller.forward();
        break;
    }

    // Reset after a shorter delay
    Future.delayed(const Duration(milliseconds: 1000), () { // Reduced from 2000
      if (mounted) {
        setState(() {
          _selectedBus = -1;
        });
        _bus1Controller.reverse();
        _bus2Controller.reverse();
        _bus3Controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _rotateController.dispose();
    _busController.dispose();
    _bus1Controller.dispose();
    _bus2Controller.dispose();
    _bus3Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: GestureDetector(
        onTap: () {
          // Allow users to skip splash screen by tapping
          if (mounted) {
            _navigateToAppropriateScreen();
          }
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.3, 0.7, 1.0],
              colors: [
                Color(0xFFFFF8DC), // Cream white
                Color(0xFFFFF176), // Light yellow
                Color(0xFFFFD54F), // Medium yellow
                Color(0xFFFFA726), // Orange yellow
              ],
            ),
          ),
          child: Stack(
            children: [
              // Animated dotted path
              _buildDottedPath(screenWidth, screenHeight),

              // Main content
              _buildMainContent(screenWidth, screenHeight),

              // Interactive bus images
              _buildInteractiveBusImages(screenWidth, screenHeight),

              // Bottom text
              _buildBottomText(screenWidth, screenHeight),

              // Skip hint (optional)
              _buildSkipHint(screenWidth, screenHeight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipHint(double screenWidth, double screenHeight) {
    return Positioned(
      top: screenHeight * 0.05,
      right: screenWidth * 0.05,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Tap to skip',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDottedPath(double screenWidth, double screenHeight) {
    return AnimatedBuilder(
      animation: _rotateAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(screenWidth, screenHeight),
          painter: DottedPathPainter(_rotateAnimation.value),
        );
      },
    );
  }

  Widget _buildMainContent(double screenWidth, double screenHeight) {
    return Stack(
      children: [
        // Location pin icon (top left)
        Positioned(
          top: screenHeight * 0.12,
          left: screenWidth * 0.05,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: const Icon(Icons.location_on, size: 30, color: Colors.black87),
          ),
        ),

        // Bus icon (top right)
        Positioned(
          top: screenHeight * 0.08,
          right: screenWidth * 0.1,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Transform.rotate(
              angle: -0.2,
              child: const Icon(
                Icons.directions_bus,
                size: 35,
                color: Colors.black87,
              ),
            ),
          ),
        ),

        // SMART text - top left with advanced typography
        Positioned(
          top: screenHeight * 0.15,
          left: screenWidth * 0.08,
          child: SlideTransition(
            position: _slideAnimation,
            child: Text(
              'Smart',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w900,
                fontSize: screenWidth * 0.15,
                color: Colors.black87,
                letterSpacing: -1,
                shadows: [
                  Shadow(
                    offset: const Offset(3, 3),
                    blurRadius: 8,
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),

        // BUS text - right side with modern stroke effect
        Positioned(
          top: screenHeight * 0.22,
          right: screenWidth * 0.08,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.5, 0.0), end: Offset.zero)
                .animate(
              CurvedAnimation(
                parent: _slideController,
                curve: Curves.elasticOut,
              ),
            ),
            child: _buildModernStrokedText(
              'Bus',
              fontSize: screenWidth * 0.15,
              fillColor: const Color(0xFFCDDC39),
              strokeColor: Colors.black87,
              strokeWidth: 3,
            ),
          ),
        ),

        // Quick & Easy circular badge with floating animation
        Positioned(
          top: screenHeight * 0.38,
          left: screenWidth * 0.25,
          right: screenWidth * 0.25,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedBuilder(
              animation: _scaleController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    math.sin(_scaleController.value * math.pi * 4) * 3,
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFEB3B), Color(0xFFFFC107)],
                      ),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Quick',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '&',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          'Easy',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveBusImages(double screenWidth, double screenHeight) {
    return Stack(
      children: [
        // Bus 1 - Left oval
        Positioned(
          top: screenHeight * 0.55,
          left: screenWidth * 0.05,
          child: _buildInteractiveBus(
            busIndex: 0,
            imagePath: 'assets/images/bus1.png',
            width: screenWidth * 0.25,
            height: screenHeight * 0.35,
            scaleAnimation: _bus1Scale,
            initialDelay: 0,
          ),
        ),

        // Bus 2 - Center oval
        Positioned(
          top: screenHeight * 0.52,
          left: screenWidth * 0.375,
          child: _buildInteractiveBus(
            busIndex: 1,
            imagePath: 'assets/images/bus2.png',
            width: screenWidth * 0.25,
            height: screenHeight * 0.38,
            scaleAnimation: _bus2Scale,
            initialDelay: 200,
          ),
        ),

        // Bus 3 - Right oval
        Positioned(
          top: screenHeight * 0.55,
          right: screenWidth * 0.05,
          child: _buildInteractiveBus(
            busIndex: 2,
            imagePath: 'assets/images/bus3.png',
            width: screenWidth * 0.25,
            height: screenHeight * 0.35,
            scaleAnimation: _bus3Scale,
            initialDelay: 400,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomText(double screenWidth, double screenHeight) {
    return Positioned(
      bottom: screenHeight * 0.05, // 5% from bottom
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: const Center(
          child: Text(
            'Efficient • Real-time • Smart',
            style: TextStyle(
              fontFamily: 'Inknut Antiqua',
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Color(0xFF014421),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveBus({
    required int busIndex,
    required String imagePath,
    required double width,
    required double height,
    required Animation<double> scaleAnimation,
    required int initialDelay,
  }) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _busController,
          curve: Interval(initialDelay / 1000, 1.0, curve: Curves.easeOutBack),
        ),
      ),
      child: AnimatedBuilder(
        animation: scaleAnimation,
        builder: (context, child) {
          bool isSelected = _selectedBus == busIndex;
          bool isOtherSelected = _selectedBus != -1 && _selectedBus != busIndex;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isOtherSelected ? 0.6 : 1.0,
            child: Transform.scale(
              scale: isOtherSelected ? 0.85 : scaleAnimation.value,
              child: GestureDetector(
                onTap: () => _onBusPressed(busIndex),
                onTapDown: (_) => _onBusPressed(busIndex),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(width / 2),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.9),
                        Colors.white.withValues(alpha: 0.7),
                      ],
                    ),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFFEB3B) : Colors.white,
                      width: isSelected ? 4 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isSelected ? 0.25 : 0.15,
                        ),
                        blurRadius: isSelected ? 30 : 20,
                        offset: Offset(0, isSelected ? 15 : 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(width / 2),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      transform: Matrix4.identity()
                        ..translate(isSelected ? 5.0 : 0.0, 0.0)
                        ..scale(isSelected ? 1.1 : 1.0),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF64B5F6), Color(0xFF1976D2)],
                              ),
                            ),
                            child: Icon(
                              Icons.directions_bus,
                              size: width * 0.4,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernStrokedText(
    String text, {
    required double fontSize,
    required Color fillColor,
    required Color strokeColor,
    required double strokeWidth,
  }) {
    return Stack(
      children: [
        // Outer glow effect
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            letterSpacing: -1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth + 2
              ..color = strokeColor.withValues(alpha: 0.3),
          ),
        ),
        // Main stroke
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            letterSpacing: -1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = strokeColor,
          ),
        ),
        // Fill with gradient effect
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [fillColor, fillColor.withValues(alpha: 0.8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class DottedPathPainter extends CustomPainter {
  final double animationValue;

  DottedPathPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Create curved dotted path
    final startX = size.width * 0.1;
    final startY = size.height * 0.2;
    final controlX = size.width * 0.6;
    final controlY = size.height * 0.35;
    final endX = size.width * 0.9;
    final endY = size.height * 0.15;

    path.moveTo(startX, startY);
    path.quadraticBezierTo(controlX, controlY, endX, endY);

    // Draw animated dotted line
    final pathMetrics = path.computeMetrics().toList();
    if (pathMetrics.isNotEmpty) {
      final pathMetric = pathMetrics.first;
      final totalLength = pathMetric.length;
      final animatedLength = totalLength * animationValue;

      for (double distance = 0; distance < animatedLength; distance += 15) {
        if ((distance / 15) % 2 == 0) {
          final pos1 = pathMetric.getTangentForOffset(distance);
          final pos2 = pathMetric.getTangentForOffset(
            math.min(distance + 8, animatedLength),
          );

          if (pos1 != null && pos2 != null) {
            canvas.drawLine(pos1.position, pos2.position, paint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}











