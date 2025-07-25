import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen2 extends StatefulWidget {
  const ForgotPasswordScreen2({super.key});

  @override
  State<ForgotPasswordScreen2> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen2> {
  final TextEditingController _contactController = TextEditingController();
  final FocusNode _contactFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();


  // Color constants
  static const Color _lightCream = Color(0xFFFFF5D6);
  static const Color _goldenYellow = Color(0xFFF5C122);
  static const Color _darkGreen = Color(0xFF004B23);
  static const Color _lightGray = Color(0xFF9E9E9E);
  static const Color _cardBackground = Color(0xFFFFFBE6);

  @override
  void dispose() {
    _contactController.dispose();
    _contactFocusNode.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onSubmitPressed() async {
    if (_isLoggedIn) {
      // In-app password change for logged-in user
      final newPassword = _newPasswordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();
      if (newPassword.isEmpty || confirmPassword.isEmpty) {
        _showErrorSnackBar("Please enter and confirm your new password");
        return;
      }
      if (newPassword != confirmPassword) {
        _showErrorSnackBar("Passwords do not match");
        return;
      }
      if (newPassword.length < 6) {
        _showErrorSnackBar("Password must be at least 6 characters");
        return;
      }
      setState(() {
        _isSubmitting = true;
      });
      try {
        await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
        setState(() {
          _isSubmitting = false;
        });
        _showSuccessDialog(message: "Password updated successfully.");
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        _showErrorSnackBar('Error: \\${e.toString()}');
      }
      return;
    }
    if (_contactController.text.trim().isEmpty) {
      _showErrorSnackBar("Please enter your contact information");
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _contactController.text.trim(),
      );
      setState(() {
        _isSubmitting = false;
      });
      _showSuccessDialog();
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      _showErrorSnackBar('Error: \\${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog({
    String message =
        "Password reset instructions have been sent to your contact information.",
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text("Success!"),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text("OK", style: TextStyle(color: _darkGreen)),
            ),
          ],
        );
      },
    );
  }

  void _useAnotherWay() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Choose Another Method",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkGreen,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.email, color: _darkGreen),
                title: const Text("Reset via Email"),
                onTap: () {
                  Navigator.pop(context);
                  // Handle email reset
                },
              ),
              ListTile(
                leading: const Icon(Icons.sms, color: _darkGreen),
                title: const Text("Reset via SMS"),
                onTap: () {
                  Navigator.pop(context);
                  // Handle SMS reset
                },
              ),
              ListTile(
                leading: const Icon(Icons.security, color: _darkGreen),
                title: const Text("Security Questions"),
                onTap: () {
                  Navigator.pop(context);
                  // Handle security questions
                },
              ),
            ],
          ),
        );
      },
    );
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
            colors: [_lightCream, _goldenYellow],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section - Back Button
                _buildBackButton(),

                const SizedBox(height: 40),

                // Lock Icon Illustration
                _buildLockIcon(),

                const SizedBox(height: 40),

                // Main Card Panel
                Expanded(
                  child: _isLoggedIn
                      ? _buildPasswordResetCard()
                      : _buildMainCard(),
                ),

                const SizedBox(height: 20),

                // Footer
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
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
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildLockIcon() {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _cardBackground.withValues(alpha: 0.8),
          border: Border.all(color: _darkGreen.withValues(alpha: 0.2), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(Icons.lock_outline, size: 60, color: _darkGreen),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            "Forgot Password!",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _darkGreen,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle
          const Text(
            "Quickly reset your password here.",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _darkGreen,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 32),

          // Input Section
          _buildContactInput(),

          const SizedBox(height: 32),

          // Submit Button
          _buildSubmitButton(),

          const SizedBox(height: 24),

          // Alternative Option
          _buildAlternativeOption(),
        ],
      ),
    );
  }

  Widget _buildContactInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _contactFocusNode.hasFocus
              ? _goldenYellow
              : _goldenYellow.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _contactController,
        focusNode: _contactFocusNode,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: _darkGreen,
        ),
        decoration: InputDecoration(
          hintText: "Enter your contact",
          hintStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: _lightGray,
          ),
          prefixIcon: const Icon(Icons.phone, color: _darkGreen, size: 24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        onTap: () {
          setState(() {});
        },
        onTapOutside: (event) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _onSubmitPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 4,
          shadowColor: _darkGreen.withValues(alpha: 0.3),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_goldenYellow),
                ),
              )
            : const Text(
                "Submit",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _goldenYellow,
                ),
              ),
      ),
    );
  }

  Widget _buildAlternativeOption() {
    return Center(
      child: GestureDetector(
        onTap: _useAnotherWay,
        child: Text(
          "Use another way.",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _lightGray,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        "Efficient • Real-time • Smart",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _darkGreen,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildPasswordResetCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Reset Password",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _darkGreen,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "New Password",
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Confirm New Password",
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _onSubmitPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Update Password",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}





