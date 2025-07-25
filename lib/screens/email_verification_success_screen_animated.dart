import 'package:flutter/material.dart';

class EmailVerificationSuccessScreenAnimated extends StatefulWidget {
  const EmailVerificationSuccessScreenAnimated({super.key});

  @override
  State<EmailVerificationSuccessScreenAnimated> createState() => 
      _EmailVerificationSuccessScreenAnimatedState();
}

class _EmailVerificationSuccessScreenAnimatedState 
    extends State<EmailVerificationSuccessScreenAnimated> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  

  // Color constants
  static const Color _lightCream = Color(0xFFFFFDF5);
  static const Color _richYellow = Color(0xFFFBC22C);
  static const Color _darkGreen = Color(0xFF004B23);
  static const Color _lightGreen = Color(0xFF9CCB3E);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    // Start animation when screen loads
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_lightCream, _richYellow],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Section - Back Button
                _buildTopSection(context),
                
                // Center Section - Main Content with Animation
                _buildAnimatedCenterSection(),
                
                // Bottom Section - Tagline
                _buildBottomSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: _darkGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCenterSection() {
    return Expanded(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Verification Success Icon
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildVerificationIcon(),
                ),
                
                const SizedBox(height: 40),
                
                // Main Headline with fade animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Text(
                    "Verification Successful.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _darkGreen,
                      height: 1.2,
                      fontFamily: 'serif',
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Subheadline with fade animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "Email Verified Successfully. You are ready to go",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: _darkGreen,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerificationIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer decorative ring
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _darkGreen.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
        ),
        
        // Middle ring
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _lightGreen.withValues(alpha: 0.1),
            border: Border.all(
              color: _lightGreen.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        
        // Main badge circle
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _darkGreen,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 50,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: const Column(
        children: [
          Text(
            "Efficient • Real-time • Smart",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _darkGreen,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}






