import 'package:flutter/material.dart';
import 'package:smart_bus_mobility_platform1/routes/app_routes.dart';
import 'package:smart_bus_mobility_platform1/resources/auth_service.dart';
import 'dart:ui';

class SignInScreenNew extends StatefulWidget {
  const SignInScreenNew({super.key});

  @override
  State<SignInScreenNew> createState() => _SignInScreenNewState();
}

class _SignInScreenNewState extends State<SignInScreenNew> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void loginUser() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Perform login
      Map<String, String> result = await AuthMethods().loginUser(
        password: _passwordController.text,
        email: _emailController.text,
      );

      // Handle result
      if (result['status'] == 'Success') {
        String role = result['role'] ?? '';
        _handleSuccessfulLogin(role);
      } else {
        _handleFailedLogin(result['status'] ?? 'Login failed');
      }
    } catch (e) {
      _handleFailedLogin('Login error: ${e.toString()}');
    }
  }

  void _handleSuccessfulLogin(String role) {
    // Reset loading state
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // Navigate based on role
    _navigateBasedOnRole(role);
  }

  void _handleFailedLogin(String message) {
    // Reset loading state
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // Show error message
    _showSnackBar(message);
  }

  void _navigateBasedOnRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        _navigateToScreen(AppRoutes.adminScreen);
        break;
      case 'user':
        _navigateToScreen(AppRoutes.passengerHomeScreen);
        break;
      case 'driver':
        _navigateToScreen(AppRoutes.busDriverHomeScreen);
        break;
      default:
        _showSnackBar('Unknown user role: $role');
        break;
    }
  }

  void _navigateToScreen(String route) {
    // Use a simple navigation approach
    Navigator.of(context).pushNamedAndRemoveUntil(route, (route) => false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(seconds: 2),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFB2FEFA),
                  Color(0xFFFFD700),
                  Color(0xFF76FF03),
                ],
                stops: [0.0, 0.7, 1.0],
              ),
            ),
          ),
          // Background with bus image and diagonal divider
          _buildBackground(),
          _buildDiagonalDivider(),
          _buildCircularOverlay(),
          // Glassmorphism main content
          _buildGlassmorphicMainContent(),
        ],
      ),
    );
  }

  Widget _buildGlassmorphicMainContent() {
    return SafeArea(
      child: Center(
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 900),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 420,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: _buildMainContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Column(
      children: [
        // Top 40% - Bus image
        Expanded(
          flex: 40,
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        // Bottom 60% - Gradient yellow
        Expanded(
          flex: 60,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFF59D), // Light yellow
                  Color(0xFFFFD700), // Rich golden yellow
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagonalDivider() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.35,
      left: 0,
      right: 0,
      child: CustomPaint(
        size: Size(MediaQuery.of(context).size.width, 100),
        painter: DiagonalDividerPainter(),
      ),
    );
  }

  Widget _buildCircularOverlay() {
    return Positioned(
      top: MediaQuery.of(context).size.height * 0.32,
      right: 30,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            // Spacer to push content down
            SizedBox(height: MediaQuery.of(context).size.height * 0.45),

            // Sign In Form
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B5E20), // Dark green
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Email Input
                    _buildInputField(
                      controller: _emailController,
                      labelText: 'Email',
                      prefixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),

                    // Password Input
                    _buildPasswordField(),
                    const SizedBox(height: 20),

                    // Remember me & Forgot password row
                    _buildRememberMeRow(),
                    const SizedBox(height: 30),

                    // Sign In Button
                    _buildSignInButton(),
                    const SizedBox(height: 30),

                    // Divider and social login
                    _buildSocialLoginSection(),
                    const SizedBox(height: 30),

                    // Footer text
                    _buildFooterText(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF1B5E20)),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1B5E20)),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF1B5E20),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildRememberMeRow() {
    return Row(
      children: [
        Checkbox(
          value: false,
          onChanged: (value) {
            // TODO: Implement remember me functionality
          },
          activeColor: const Color(0xFF1B5E20),
        ),
        const Text('Remember me', style: TextStyle(color: Color(0xFF1B5E20))),
        const Spacer(),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.forgotPasswordScreen);
          },
          child: const Text(
            'Forgot Password?',
            style: TextStyle(color: Color(0xFF1B5E20)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : loginUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20), // Dark green
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 3,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildSocialLoginSection() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(color: Colors.black)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Continue with',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.7),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Montserrat',
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Colors.black)),
          ],
        ),
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 20),
                child: child,
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFancySocialLogoButton(
                assetPath: 'assets/images/instagram.png',
                semanticLabel: 'Sign in with Instagram',
                onTap: _handleInstagramSignIn,
                glowColor: const Color(0xFFE1306C),
              ),
              const SizedBox(width: 24),
              _buildFancySocialLogoButton(
                assetPath: 'assets/images/facebook.png',
                semanticLabel: 'Sign in with Facebook',
                onTap: _handleFacebookSignIn,
                glowColor: const Color(0xFF1877F2),
              ),
              const SizedBox(width: 24),
              _buildFancySocialLogoButton(
                assetPath: 'assets/images/Google.png',
                semanticLabel: 'Sign in with Google',
                onTap: _handleGoogleSignIn,
                glowColor: const Color(0xFFDB4437),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final result = await AuthMethods().signInWithGoogle();
    setState(() => _isLoading = false);
    if (result['status'] == 'Success') {
      _navigateBasedOnRole(result['role'] ?? 'user');
    } else {
      _showSnackBar(result['status'] ?? 'Google sign in failed');
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() => _isLoading = true);
    final result = await AuthMethods().signInWithFacebook();
    setState(() => _isLoading = false);
    if (result['status'] == 'Success') {
      _navigateBasedOnRole(result['role'] ?? 'user');
    } else {
      _showSnackBar(result['status'] ?? 'Facebook sign in failed');
    }
  }

  Future<void> _handleInstagramSignIn() async {
    setState(() => _isLoading = true);
    try {
      await AuthMethods().signInWithInstagram();
    } catch (e) {
      _showSnackBar('Instagram sign in not available');
    }
    setState(() => _isLoading = false);
  }

  Widget _buildSocialLogoButton({
    required String assetPath,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }

  Widget _buildFancySocialLogoButton({
    required String assetPath,
    required String semanticLabel,
    required VoidCallback onTap,
    required Color glowColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.95),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.25),
                blurRadius: 18,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: glowColor.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(color: Colors.grey[600]),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.signUpScreen);
          },
          child: const Text(
            'Sign Up',
            style: TextStyle(
              color: Color(0xFF1B5E20),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom painter for diagonal divider
class DiagonalDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height * 0.7);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}









