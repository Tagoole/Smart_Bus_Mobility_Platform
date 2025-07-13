import 'package:flutter/material.dart';
import 'paymentsuccess_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreen();
}

class _PaymentScreen extends State<PaymentScreen> {
  bool isManualSelected = true;
  bool isMTNSelected = true;
  String selectedProvider = 'Select Your Service Provider';
  final TextEditingController amountController = TextEditingController();
  int selectedNavIndex = 4; // Send/Pay is highlighted

  final List<String> serviceProviders = [
    'Select Your Service Provider',
    'MTN Mobile Money',
    'Airtel Money',
    'Vodafone Cash',
    'AirtelTigo Money',
  ];

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
                _buildPaymentToggle(),
                if (isManualSelected) _buildManualPaymentSection(),
                if (!isManualSelected) _buildOnlinePaymentSection(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // Move all widget helper functions that use setState into the State class as methods

  Widget _buildTopSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Payment Options',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Icon(Icons.arrow_drop_down, color: Colors.yellow.shade600, size: 30),
        ],
      ),
    );
  }

  Widget _buildPaymentToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isManualSelected = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: isManualSelected
                      ? Colors.green.withValues(alpha: 0.8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isManualSelected
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_android,
                      color: isManualSelected
                          ? Colors.white
                          : Colors.grey.shade300,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Manual (Momo/Airtel)',
                      style: TextStyle(
                        color: isManualSelected
                            ? Colors.white
                            : Colors.grey.shade300,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isManualSelected = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: !isManualSelected
                      ? Colors.green.withValues(alpha: 0.8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: !isManualSelected
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: !isManualSelected
                          ? Colors.white
                          : Colors.grey.shade300,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Online (Visa Card)',
                      style: TextStyle(
                        color: !isManualSelected
                            ? Colors.white
                            : Colors.grey.shade300,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualPaymentSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
                'Manual Payment',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMTNAirtelToggle(),
          const SizedBox(height: 20),
          _buildServiceProviderDropdown(),
          const SizedBox(height: 20),
          _buildAmountInput(),
          const SizedBox(height: 15),
          _buildInstructionalText(),
        ],
      ),
    );
  }

  Widget _buildMTNAirtelToggle() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => isMTNSelected = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: isMTNSelected
                    ? Colors.amber
                    : Colors.amber.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                boxShadow: isMTNSelected
                    ? [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'MTN',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isMTNSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => isMTNSelected = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: !isMTNSelected
                    ? Colors.redAccent
                    : Colors.redAccent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                boxShadow: !isMTNSelected
                    ? [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: const Text(
                'Airtel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceProviderDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedProvider,
          isExpanded: true,
          dropdownColor: Colors.grey.shade800,
          style: TextStyle(color: Colors.yellow.shade600),
          icon: Icon(Icons.arrow_drop_down, color: Colors.yellow.shade600),
          items: serviceProviders.map((String provider) {
            return DropdownMenuItem<String>(
              value: provider,
              child: Text(provider),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              selectedProvider = newValue!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildAmountInput() {
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController pinController = TextEditingController();

    return Column(
      children: [
        // Amount input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
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
            color: Colors.black.withValues(alpha: 0.3),
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
              // Prompt for PIN
              String? pin = await showDialog<String>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Enter your PIN'),
                    content: TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'PIN'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(pinController.text),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
              if (pin != null && pin.isNotEmpty) {
                // Simulate deduction
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'UGX ${amountController.text} deducted from ${phoneController.text}',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                bool paymentSuccess =
                    true; // Replace with your actual payment result

                if (paymentSuccess) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PaymentSuccess(),
                    ),
                  );
                } else {
                  
                }
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
      'Message should appear on phone for you to put in your PIN',
      style: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildOnlinePaymentSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
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
              Icon(Icons.credit_card, color: Colors.yellow.shade600, size: 24),
              const SizedBox(width: 10),
              const Text(
                'Online Payment (Visa Card)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildCardInput('Card Number', '1234 5678 9012 3456'),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildCardInput('Expiry Date', '12/25')),
              const SizedBox(width: 15),
              Expanded(child: _buildCardInput('CVV', '123')),
            ],
          ),
          const SizedBox(height: 15),
          _buildCardInput('Cardholder Name', 'John Doe'),
          const SizedBox(height: 15),
          // Add amount input field here
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: TextField(
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.yellow.shade600),
              decoration: InputDecoration(
                hintText: 'Enter amount to pay',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.attach_money,
                  color: Colors.yellow.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          // Add Pay Now button here
          Center(
            child: ElevatedButton(
              onPressed: () {
                // Simulate payment deduction logic here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Amount deducted from credit card!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.yellow.shade600,
                foregroundColor: Colors.green.shade900,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
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
      ),
    );
  }

  Widget _buildCardInput(String label, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.yellow.shade600,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hint,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
