import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentSuccess extends StatelessWidget {
  const PaymentSuccess({Key? key}) : super(key: key);

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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
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
                        _buildDetailRow("Date", "12th June, 2025"),
                        const SizedBox(height: 15),
                        _buildDetailRow("Type of transaction", "Credit card"),
                        const SizedBox(height: 15),
                        _buildDetailRow("Amount", "Sh.25,000"),
                        const SizedBox(height: 15),
                        _buildDetailRow("Status", "Success", isStatus: true),
                        const SizedBox(height: 30),
                        
                        // QR Code Icon
                        Icon(
                          Icons.qr_code_2,
                          size: 50,
                          color: Colors.black,
                        ),
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



  Widget _buildNavIcon(IconData icon, bool isEmphasized) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isEmphasized ? Colors.greenAccent : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () {
          // Add navigation logic here
        },
        icon: Icon(
          icon,
          color: Colors.black,
          size: 20,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
