import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'customer_home_screen.dart';
import 'nav_bar_screen.dart';

class PaymentSuccess extends StatefulWidget {
  const PaymentSuccess({super.key});

  @override
  State<PaymentSuccess> createState() => _PaymentSuccessState();
}

class _PaymentSuccessState extends State<PaymentSuccess> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const NavBarScreen(userRole: 'user', initialTab: 0),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromARGB(255, 148, 181, 111),
              Colors.green[900]!,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Section - Success Icon
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.yellowAccent,
                    child: Icon(
                      Icons.check,
                      color: Colors.green[900],
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Success Text
                  Text(
                    "Payment Successful!",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.yellowAccent[700],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Payment Details Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.yellowAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Payment Details",
                          style: GoogleFonts.poppins(
                            color: Colors.yellowAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Payment Details Card
                  Container(
                    width: 300,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Column(
                      children: [
                        // Transaction Details Rows
                        _buildDetailRow("Transaction ID", "4233456786844"),
                        const SizedBox(height: 15),
                        _buildDetailRow("Date", formatDate(DateTime.now())),
                        const SizedBox(height: 15),
                        _buildDetailRow("Type of transaction", "Credit card"),
                        const SizedBox(height: 15),
                        _buildDetailRow("Amount", "Sh.25,000"),
                        const SizedBox(height: 15),
                        _buildDetailRow("Status", "Success", isStatus: true),
                        const SizedBox(height: 30),

                        
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Tagline
                  Text(
                    "Efficient *Real-time *Smart",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.yellowAccent,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // You can add more widgets here if needed
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.yellowAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: isStatus ? Colors.greenAccent : Colors.white,
            fontSize: 14,
            fontWeight: isStatus ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String formatDate(DateTime date) {
    final daySuffix = _getDayOfMonthSuffix(date.day);
    final formatted =
        DateFormat('EEEE d').format(date) +
        daySuffix +
        DateFormat(' MMMM, yyyy').format(date);
    return formatted;
  }

  String _getDayOfMonthSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}












