import 'package:flutter/material.dart';
import 'package:smart_bus_mobility_platform1/resources/auth_service.dart';
import 'package:smart_bus_mobility_platform1/routes/app_routes.dart';
import 'package:smart_bus_mobility_platform1/utils/utils.dart';
import 'package:flutter/gestures.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

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

  void _navigateBasedOnRole(String role) {
    print('Navigating based on role: $role');

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

    if (mounted) {
      try {
        Navigator.pushReplacementNamed(context, targetRoute);
      } catch (e) {
        print('Navigation error: $e');
        if (mounted) {
          showSnackBar('Navigation failed. Please try again.', context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Add this to prevent keyboard from resizing the screen
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        // Dismiss keyboard when tapping outside
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Container(
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(30)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(30)),
            child: Stack(
              children: [
                // Fixed background that won't move
                _buildFixedBackground(),

                // Scrollable content overlay
                _buildScrollableContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedBackground() {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Positioned.fill(
      child: Column(
        children: [
          // Top section with bus image - fixed height
          Container(
            height: screenHeight * 0.4,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?ixlib=rb-4.0.3&auto=format&fit=crop&w=1000&q=80',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                // Gradient overlay for better text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                        const Color(0xFFFFF59D).withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
                // Circular overlay positioned absolutely
                Positioned(
                  bottom: -30,
                  right: 30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://images.unsplash.com/photo-1570125909232-eb263c188f7e?ixlib=rb-4.0.3&auto=format&fit=crop&w=400&q=80',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF1B5E20),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 40,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom section with gradient - takes remaining space
          Expanded(
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
      ),
    );
  }

  Widget _buildScrollableContent() {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Positioned.fill(
      child: SafeArea(
        child: SingleChildScrollView(
          // Add physics for better scroll behavior
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Spacer to position content below the image
                  SizedBox(height: screenHeight * 0.35),
                  
                  // Sign In Form Container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title
                        const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Email Input
                        _buildInputField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
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
                        const SizedBox(height: 20),

                        // Footer text
                        _buildFooterText(),
                      ],
                    ),
                  ),
                  
                  // Bottom padding
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: focusNode.hasFocus 
              ? const Color(0xFF1B5E20) 
              : const Color(0xFF8BC34A),
          width: focusNode.hasFocus ? 2.5 : 2,
        ),
        boxShadow: focusNode.hasFocus ? [
          BoxShadow(
            color: const Color(0xFF8BC34A).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: focusNode.hasFocus 
                ? const Color(0xFF1B5E20) 
                : const Color(0xFF1B5E20).withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            prefixIcon, 
            color: focusNode.hasFocus 
                ? const Color(0xFF1B5E20) 
                : const Color(0xFF1B5E20).withOpacity(0.7),
          ),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        onTap: () {
          setState(() {}); // Trigger rebuild for focus animation
        },
      ),
    );
  }

  Widget _buildPasswordField() {
    return _buildInputField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      labelText: 'Password',
      prefixIcon: Icons.lock_outline,
      obscureText: _obscurePassword,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility_off : Icons.visibility,
          color: _passwordFocusNode.hasFocus 
              ? const Color(0xFF1B5E20) 
              : const Color(0xFF1B5E20).withOpacity(0.7),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Text(
              'Remember me',
              style: TextStyle(
                color: Color(0xFF1B5E20),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.forgotPasswordScreen);
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
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
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : loginUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1B5E20),
          disabledBackgroundColor: const Color(0xFF1B5E20).withOpacity(0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 8,
          shadowColor: const Color(0xFF1B5E20).withOpacity(0.3),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  color: Color(0xFF76FF03),
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
            const Expanded(
              child: Divider(
                color: Colors.grey,
                thickness: 1,
              ),
            ),
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
            const Expanded(
              child: Divider(
                color: Colors.grey,
                thickness: 1,
              ),
            ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
              errorBuilder: (context, error, stackTrace) {
                // Fallback icon if image fails to load
                return Icon(
                  Icons.login,
                  color: Colors.grey.shade600,
                  size: 24,
                );
              },
            ),
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
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: 'Sign Up',
              style: const TextStyle(
                color: Color(0xFF1B5E20),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                fontSize: 14,
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
