import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'forgot_password_screen2.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isEmailValid = false;


  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  void _validateEmail() {
    final isValid = _isValidEmail(_emailController.text);
    setState(() {
      _isEmailValid = isValid;
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
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
            colors: [
              Color(0xFFFFFFFF), // White at top
              Color(0xFFFFD54F), // Yellow/orange at bottom
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Top Navigation - Back Button
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF004D00),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
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
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Lock Icon Section
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF004D00).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 50,
                      color: Color(0xFF004D00),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Form Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD), // Light yellow
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Headline
                          const Text(
                            'Forgot Password!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF004D00),
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 12),

                          // Subtext
                          const Text(
                            'Quickly reset your password here.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF004D00),
                              fontFamily: 'Poppins',
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 32),

                          // Email Input Field
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: const Color(
                                  0xFF9ACD32,
                                ), // Light yellow-green
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  // ignore: deprecated_member_use
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'Enter your email',
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF004D00),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF004D00),
                                fontFamily: 'Poppins',
                              ),
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
                          ),

                          const SizedBox(height: 32),

                          // Submit Button
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isEmailValid ? _sendResetEmail : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF004D00),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: const Text(
                                'Send Reset Link',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Alternate Option
                  GestureDetector(
                    onTap: () {
                      // Handle alternate way
                      _showAlternateOptions(context);
                    },
                    child: const Text(
                      'Use another way.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Footer Motto
                  const Text(
                    'Efficient • Real-time • Smart',
                    style: TextStyle(
                      color: Color(0xFF004D00),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ForgotPasswordScreen2(),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: \\${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAlternateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Another Way',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004D00),
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 20),

              // SMS Option
              ListTile(
                leading: const Icon(
                  Icons.sms_outlined,
                  color: Color(0xFF004D00),
                ),
                title: const Text(
                  'Reset via SMS',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF004D00),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Handle SMS reset
                },
              ),

              // Call Support Option
              ListTile(
                leading: const Icon(
                  Icons.phone_outlined,
                  color: Color(0xFF004D00),
                ),
                title: const Text(
                  'Call Support',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF004D00),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // Handle call support
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}


