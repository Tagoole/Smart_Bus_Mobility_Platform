/*import 'package:flutter/material.dart';
import 'package:smart_bus_mobility_platform1/routes/app_routes.dart';
import 'package:smart_bus_mobility_platform1/resources/auth_service.dart';

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
            Expanded(child: Divider(color: Colors.grey[400])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or continue with',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSocialButton(
              icon: 'assets/images/Google.png',
              onPressed: () {
                // TODO: Implement Google sign in
              },
            ),
            _buildSocialButton(
              icon: 'assets/images/facebook.png',
              onPressed: () {
                // TODO: Implement Facebook sign in
              },
            ),
            _buildSocialButton(
              icon: 'assets/images/apple.png',
              onPressed: () {
                // TODO: Implement Apple sign in
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Image.asset(icon, width: 24, height: 24),
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
*/
