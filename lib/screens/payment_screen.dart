import 'package:flutter/material.dart';
import 'paymentsuccess_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/momo_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreen();
}

class _PaymentScreen extends State<PaymentScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade900, Colors.teal.shade700],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildTopSection(),
                const SizedBox(height: 20),
                _buildMTNPaymentSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'MTN Mobile Money Payment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMTNPaymentSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_android,
                color: Colors.yellow.shade600,
                size: 24,
              ),
              const SizedBox(width: 10),
              const Text(
                'MTN MoMo Payment',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildAmountInput(),
          const SizedBox(height: 15),
          _buildInstructionalText(),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      children: [
        // Amount input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: TextField(
            controller: amountController,
            style: TextStyle(color: Colors.yellow.shade600),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter amount you are paying',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
              suffixIcon: Icon(Icons.edit, color: Colors.yellow.shade600),
            ),
          ),
        ),
        const SizedBox(height: 15),
        // Telephone number input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: TextField(
            controller: phoneController,
            style: TextStyle(color: Colors.yellow.shade600),
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Enter telephone number',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.phone, color: Colors.yellow.shade600),
            ),
          ),
        ),
        const SizedBox(height: 15),
        // Pay Now button
        Center(
          child: ElevatedButton(
            onPressed: () async {
              final phone = phoneController.text.trim();
              final amount = amountController.text.trim();
              if (phone.isEmpty || amount.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter phone and amount')),
                );
                return;
              }

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Processing payment...'),
                    ],
                  ),
                ),
              );

              try {
                // 1. Initiate payment request to your backend
                final response = await http.post(
                  Uri.parse('https://api-abp277afba-uc.a.run.app/api/requesttopay'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'amount': amount,
                    'currency': 'UGX',
                    'externalId': 'ticket_${DateTime.now().millisecondsSinceEpoch}',
                    'payer': {'partyIdType': 'MSISDN', 'partyId': phone},
                    'payerMessage': 'Ticket payment',
                    'payeeNote': 'Smart Bus Ticket',
                  }),
                );

                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  final referenceId = data['referenceId'];

                  // 2. Poll for payment status
                  bool paymentSuccess = false;
                  for (int i = 0; i < 15; i++) {
                    await Future.delayed(const Duration(seconds: 2));
                    final statusResp = await http.get(
                      Uri.parse('https://api-abp277afba-uc.a.run.app/api/transaction/$referenceId'),
                    );
                    if (statusResp.statusCode == 200) {
                      final statusData = jsonDecode(statusResp.body);
                      final status = statusData['data']['status'];
                      if (status == 'SUCCESSFUL') {
                        paymentSuccess = true;
                        break;
                      } else if (status == 'FAILED') {
                        break;
                      }
                    }
                  }

                  Navigator.of(context).pop(); // Dismiss loading dialog

                  if (paymentSuccess) {
                    // Mark ticket as paid in Firestore
                    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                    final bookingId = args != null ? args['bookingId'] : null;
                    if (bookingId != null) {
                      await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({'isPaid': true});
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PaymentSuccess()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment failed or timed out')),
                    );
                  }
                } else {
                  Navigator.of(context).pop(); // Dismiss loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Payment initiation failed: ${response.body}')),
                  );
                }
              } catch (e) {
                Navigator.of(context).pop(); // Dismiss loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow.shade600,
              foregroundColor: Colors.green.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Pay Now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionalText() {
    return Text(
      'You will receive a prompt on your phone to approve the payment.',
      style: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}



