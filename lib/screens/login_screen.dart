import 'package:flutter/material.dart';
import 'package:smart_bus_mobility_platform1/resources/auth_service.dart';
import 'package:smart_bus_mobility_platform1/routes/app_routes.dart';
import 'package:smart_bus_mobility_platform1/utils/utils.dart';
import 'package:flutter/gestures.dart';

// work on remember me
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  void loginUser() async {
    setState(() {
      _isLoading = true;
    });
    Map<String, String> result = await AuthMethods().loginUser(
      password: _passwordController.text,
      email: _emailController.text,
    );

    _handleLoginResult(result);
  }

  void _handleLoginResult(Map<String, dynamic> result) async {
    if (result['status'] == 'Success') {
      print('Logging in was a success');
      String role = result['role'] ?? '';

      // Reset loading state before navigation
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _navigateBasedOnRole(role);
    } else {
      if (mounted) {
        showSnackBar(result['status'] ?? 'Login failed', context);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // method to navigate user to appropriate page after login success
  /*
  void _navigateBasedOnRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        Navigator.pushReplacementNamed(context, AppRoutes.adminScreen);
        break;
      case 'user':
        Navigator.pushReplacementNamed(context, AppRoutes.passengerHomeScreen);
        break;
      case 'driver':
        Navigator.pushReplacementNamed(context, AppRoutes.busDriverHomeScreen);
      default:
        showSnackBar('Unknown user role: $role', context);
        Navigator.pushReplacementNamed(context, AppRoutes.loginScreen);
        break;
    }
  }
  */
  void _navigateBasedOnRole(String role) {
    print('Navigating based on role: $role');

    // Check if widget is still mounted before navigation
    if (!mounted) {
      print('Widget unmounted, cannot navigate');
      return;
    }

    String? targetRoute;

    switch (role.toLowerCase()) {
      case 'admin':
        print('Navigating to admin screen');
        targetRoute = AppRoutes.adminScreen;
        break;
      case 'user':
        print('Navigating to passenger map screen');
        targetRoute = AppRoutes.passengerHomeScreen;
        break;
      case 'driver':
        print('Navigating to driver navbar screen');
        targetRoute = AppRoutes.driverNavbarScreen;
        break;
      default:
        print('Unknown role: $role, showing error');
        if (mounted) {
          showSnackBar('Unknown user role: $role', context);
        }
        return;
    }

    // Perform navigation if we have a valid route
    if (mounted) {
      try {
        Navigator.pushReplacementNamed(context, targetRoute);
      } catch (e) {
        print('Navigation error: $e');
        // Handle navigation error
        if (mounted) {
          showSnackBar('Navigation failed. Please try again.', context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(30)),
          child: Stack(
            children: [
              // Background with luxury bus image
              _buildBackground(),

              // Diagonal divider
              _buildDiagonalDivider(),

              // Circular profile overlay
              _buildCircularOverlay(),

              // Main content
              _buildMainContent(),
            ],
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
                      labelText: 'Email', // <-- Use labelText
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
        border: Border.all(
          color: const Color(0xFF8BC34A), // Lime green
          width: 2,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: labelText, // <-- Use labelText for floating label
          labelStyle: const TextStyle(
            color: Color(0xFF1B5E20), // Dark green
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF1B5E20)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        style: const TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildPasswordField() {
    return _buildInputField(
      controller: _passwordController,
      labelText: 'Password', // <-- Use labelText
      prefixIcon: Icons.lock_outline,
      obscureText: _obscurePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility_off : Icons.visibility,
          color: const Color(0xFF1B5E20),
        ),
        onPressed: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
      ),
    );
  }

  Widget _buildRememberMeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: (value) {
                setState(() {
                  _rememberMe = value ?? false;
                });
              },
              activeColor: const Color(0xFF1B5E20),
            ),
            const Text(
              'Remember me',
              style: TextStyle(color: Color(0xFF1B5E20), fontSize: 14),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.forgotPasswordScreen);
          },
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              color: Color(0xFF1B5E20),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
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
        onPressed: loginUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20), // Dark green
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 8,
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Sign In',
                style: TextStyle(
                  color: Color(0xFF76FF03), // Neon green
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Expanded(child: Divider(color: Colors.black)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialLogoButton(
              assetPath: 'assets/images/instagram.png',
              semanticLabel: 'Sign in with Instagram',
              onTap: () {},
            ),
            const SizedBox(width: 24),
            _buildSocialLogoButton(
              assetPath: 'assets/images/facebook.png',
              semanticLabel: 'Sign in with Facebook',
              onTap: () {},
            ),
            const SizedBox(width: 24),
            _buildSocialLogoButton(
              assetPath: 'assets/images/Google.png',
              semanticLabel: 'Sign in with Google',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
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

  Widget _buildFooterText() {
    return Center(
      child: RichText(
        text: TextSpan(
          text: "Don't have an account? ",
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(
              text: 'Sign Up',
              style: const TextStyle(
                color: Color(0xFF1B5E20),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  Navigator.pushNamed(context, AppRoutes.signUpScreen);
                },
            ),
          ],
        ),
      ),
    );
  }
}

class DiagonalDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFF59D) // Light yellow
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}





