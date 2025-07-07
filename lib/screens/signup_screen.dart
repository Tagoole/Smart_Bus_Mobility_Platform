import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(); // Added username controller
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _selectedRole;
  bool _isFormValid = false;
  final List<String> _roles = ['User', 'Driver', 'Admin']; // Added Admin role back

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_validateForm); // Added username listener
    _emailController.addListener(_validateForm);
    _contactController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
  }

  void _validateForm() {
    final isUsernameValid = _usernameController.text.isNotEmpty &&
                           _usernameController.text.length >= 3; // Added username validation
    final isEmailValid = _isValidEmail(_emailController.text);
    final isContactValid =
        _contactController.text.isNotEmpty &&
        _isNumeric(_contactController.text);
    final isPasswordValid = _passwordController.text.isNotEmpty;
    final isConfirmPasswordValid =
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text;
    final isRoleSelected = _selectedRole != null;

    setState(() {
      _isFormValid =
          isUsernameValid && // Added username validation to form validation
          isEmailValid &&
          isContactValid &&
          isPasswordValid &&
          isConfirmPasswordValid &&
          isRoleSelected;
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isNumeric(String str) {
    return RegExp(r'^[0-9]+$').hasMatch(str);
  }

  // Added username validation method
  bool _isValidUsername(String username) {
    // Username should be at least 3 characters and contain only letters, numbers, and underscores
    return RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(username);
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
            stops: [0.0, 0.4, 1.0],
            colors: [
              Color(0xFF87CEEB), // Sky blue for mountain background
              Color(0xFFFFEB3B), // Yellow transition
              Color(0xFFFFF176), // Light yellow at bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top section with background image
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      'assets/images/bus_sign_in.png',
                    ), // Add your bus and mountains image
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    // Back button
                    Positioned(
                      top: 16,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF014421),
                          ),
                        ),
                      ),
                    ),
                    // Profile placeholder
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          image: const DecorationImage(
                            image: AssetImage(
                              'assets/images/bus2_sign_in.png',
                            ), // Add bus interior thumbnail
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Form section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Username Field - Added as first field
                        _buildTextField(
                          controller: _usernameController,
                          hintText: 'Enter your username',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a username';
                            }
                            if (value.length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            if (!_isValidUsername(value)) {
                              return 'Username can only contain letters, numbers, and underscores';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Email Field
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'Enter your email',
                          prefixIcon: Icons.email_outlined,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!_isValidEmail(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Contact Field
                        _buildTextField(
                          controller: _contactController,
                          hintText: 'Contact',
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your contact number';
                            }
                            if (!_isNumeric(value)) {
                              return 'Please enter a valid contact number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Password Field
                        _buildTextField(
                          controller: _passwordController,
                          hintText: 'Password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF9CCB3E),
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Confirm Password Field
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hintText: 'Confirm Password',
                          prefixIcon: Icons.lock_outline,
                          obscureText: !_isConfirmPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF9CCB3E),
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Role Dropdown
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFF9CCB3E),
                              width: 1,
                            ),
                          ),
                          child: DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              hintText: 'Role',
                              prefixIcon: Icon(
                                Icons.work_outline,
                                color: Color(0xFF9CCB3E),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            borderRadius: BorderRadius.circular(30),
                            items: _roles.map((String role) {
                              return DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedRole = newValue;
                              });
                              _validateForm();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a role';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isFormValid ? _handleSignUp : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFormValid
                                  ? const Color(0xFF014421)
                                  : Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                color: Color(0xFFFFEB3B),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Footer Text
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                color: Color(0xFF014421),
                                fontSize: 16,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                // Navigate to Sign In screen
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/signin',
                                );
                              },
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: Color(0xFFFFEB3B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF9CCB3E), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9CCB3E).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF9CCB3E)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        onChanged: (value) => _validateForm(),
      ),
    );
  }

  void _handleSignUp() {
    if (_formKey.currentState!.validate()) {
      // Handle sign up logic here with username included
      print('Username: ${_usernameController.text}');
      print('Email: ${_emailController.text}');
      print('Contact: ${_contactController.text}');
      print('Role: $_selectedRole');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign up successful!'),
          backgroundColor: Color(0xFF014421),
        ),
      );
      // Navigate to next screen or perform sign up
    }
  }

  @override
  void dispose() {
    _usernameController.dispose(); // Added username controller disposal
    _emailController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}