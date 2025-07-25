import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'email_verification_success_screen_animated.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  
  const EmailVerificationScreen({
    super.key,
    this.email = "example@gmail.com",
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}


class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  String _currentPin = "";
  bool _isButtonEnabled = false;

  // Color constants
  static const Color _lightCream = Color(0xFFFFF5D6);
  static const Color _goldenYellow = Color(0xFFF5C122);
  static const Color _darkGreen = Color(0xFF004B23);
  static const Color _lightYellow = Color(0xFFFFF8E1);

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(String value, int index) {
    setState(() {
      _currentPin = _controllers.map((c) => c.text).join();
      _isButtonEnabled = _currentPin.length == 6;
    });

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  void _navigateToSuccessScreen() {
    // Navigate to the animated success screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const EmailVerificationSuccessScreenAnimated(),
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text("Invalid Code"),
            ],
          ),
          content: const Text("The verification code you entered is incorrect. Please try again."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Clear the PIN fields
                _clearPinFields();
              },
              child: const Text("Try Again"),
            ),
          ],
        );
      },
    );
  }

  void _clearPinFields() {
    for (var controller in _controllers) {
      controller.clear();
    }
    setState(() {
      _currentPin = "";
      _isButtonEnabled = false;
    });
    _focusNodes[0].requestFocus();
  }

  void _onContinuePressed() {
    if (_currentPin.length == 6) {
      // Validate the pin code here
      _validateCode(_currentPin);
    }
  }

  void _validateCode(String code) {
    // Add your validation logic here
    // Simulate validation process
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Validating code..."),
            ],
          ),
        );
      },
    );

    // Simulate API call delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Close loading dialog
      
      // Example validation logic (replace with your actual validation)
      if (code == "123456") {
        // Success case - Navigate to animated success screen
        _navigateToSuccessScreen();
      } else {
        // Error case
        _showErrorDialog();
      }
    });
  }

  void _resendCode() {
    // Add resend code logic here
    // Show loading state
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text("Sending code..."),
          ],
        ),
        backgroundColor: _darkGreen,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Verification code sent successfully!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_lightCream, _goldenYellow],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar - Back Button
                _buildBackButton(),
                
                const SizedBox(height: 40),
                
                // Icon Section
                _buildFingerprintIcon(),
                
                const SizedBox(height: 40),
                
                // Main Card
                Expanded(
                  child: _buildMainCard(),
                ),
                
                const SizedBox(height: 20),
                
                // Bottom Tagline
                _buildBottomTagline(),
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
        ),
        child: const Icon(
          Icons.arrow_back,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildFingerprintIcon() {
    return Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _lightCream.withValues(alpha: 0.8),
          border: Border.all(
            color: _darkGreen.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.fingerprint,
          size: 60,
          color: _darkGreen,
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _lightCream.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
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
            "Verify Your Email.",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _darkGreen,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Subtitle
          const Text(
            "Enter the 6-Digit verification code sent to",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: _darkGreen,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Email
          Text(
            widget.email,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _darkGreen,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // PIN Code Input
          _buildPinCodeInput(),
          
          const SizedBox(height: 32),
          
          // Continue Button
          _buildContinueButton(),
          
          const SizedBox(height: 24),
          
          // Resend Code Section
          _buildResendSection(),
        ],
      ),
    );
  }

  Widget _buildPinCodeInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return Container(
          width: 48,
          height: 56,
          decoration: BoxDecoration(
            color: _lightYellow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focusNodes[index].hasFocus ? _darkGreen : _darkGreen.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: TextField(
            controller: _controllers[index],
            focusNode: _focusNodes[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _darkGreen,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: "",
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) {
              _onPinChanged(value, index);
            },
            onTap: () {
              setState(() {});
            },
            onEditingComplete: () {
              setState(() {});
            },
            onTapOutside: (event) {
              setState(() {});
            },
          ),
        );
      }),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isButtonEnabled ? _onContinuePressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isButtonEnabled ? _darkGreen : _darkGreen.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: _isButtonEnabled ? 4 : 0,
        ),
        child: const Text(
          "Continue",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _goldenYellow,
          ),
        ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Center(
      child: RichText(
        text: TextSpan(
          children: [
            const TextSpan(
              text: "Didn't receive any code? ",
              style: TextStyle(
                fontSize: 14,
                color: _darkGreen,
                fontWeight: FontWeight.w400,
              ),
            ),
            WidgetSpan(
              child: GestureDetector(
                onTap: _resendCode,
                child: const Text(
                  "Resend Code.",
                  style: TextStyle(
                    fontSize: 14,
                    color: _goldenYellow,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTagline() {
    return const Center(
      child: Text(
        "Efficient • Real-time • Smart",
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _darkGreen,
        ),
      ),
    );
  }
}






