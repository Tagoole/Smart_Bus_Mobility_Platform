import 'package:flutter/material.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  String _selectedRoute = 'Route 101 - Downtown Express';
  String _selectedTicketType = 'Single Journey';
  String _selectedPaymentMethod = 'Credit Card';

  final List<String> _routes = [
    'Route 101 - Downtown Express',
    'Route 102 - Airport Shuttle',
    'Route 103 - University Line',
    'Route 104 - Shopping Mall',
    'Route 105 - Hospital Express',
  ];

  final List<String> _ticketTypes = [
    'Single Journey',
    'Daily Pass',
    'Weekly Pass',
    'Monthly Pass',
  ];

  final List<String> _paymentMethods = [
    'Credit Card',
    'Debit Card',
    'Mobile Money',
    'Cash',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Tickets'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[700]!, Colors.green[100]!, Colors.green[50]!],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.confirmation_number,
                          color: Colors.green[700],
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Purchase Your Ticket',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select your route and ticket type',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Route Selection
                _buildSelectionCard(
                  title: 'Select Route',
                  subtitle: 'Choose your destination',
                  icon: Icons.route,
                  selectedValue: _selectedRoute,
                  options: _routes,
                  onChanged: (value) {
                    setState(() {
                      _selectedRoute = value!;
                    });
                  },
                ),

                const SizedBox(height: 20),

                // Ticket Type Selection
                _buildSelectionCard(
                  title: 'Ticket Type',
                  subtitle: 'Choose your ticket duration',
                  icon: Icons.access_time,
                  selectedValue: _selectedTicketType,
                  options: _ticketTypes,
                  onChanged: (value) {
                    setState(() {
                      _selectedTicketType = value!;
                    });
                  },
                ),

                const SizedBox(height: 20),

                // Payment Method Selection
                _buildSelectionCard(
                  title: 'Payment Method',
                  subtitle: 'Choose how to pay',
                  icon: Icons.payment,
                  selectedValue: _selectedPaymentMethod,
                  options: _paymentMethods,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentMethod = value!;
                    });
                  },
                ),

                const SizedBox(height: 30),

                // Price Summary
                _buildPriceSummary(),

                const SizedBox(height: 30),

                // Purchase Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    onPressed: _purchaseTicket,
                    child: const Text(
                      'Purchase Ticket',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Recent Tickets
                Text(
                  'Recent Tickets',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                _buildRecentTicketCard(
                  route: 'Route 101 - Downtown Express',
                  type: 'Single Journey',
                  date: 'Today, 2:30 PM',
                  status: 'Active',
                  color: Colors.green,
                ),

                const SizedBox(height: 15),

                _buildRecentTicketCard(
                  route: 'Route 102 - Airport Shuttle',
                  type: 'Daily Pass',
                  date: 'Yesterday, 9:15 AM',
                  status: 'Used',
                  color: Colors.grey,
                ),

                const SizedBox(height: 15),

                _buildRecentTicketCard(
                  route: 'Route 103 - University Line',
                  type: 'Weekly Pass',
                  date: '3 days ago',
                  status: 'Expired',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String selectedValue,
    required List<String> options,
    required Function(String?) onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.green[700], size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            value: selectedValue,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.green[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.green[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.green[700]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.green[50],
            ),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary() {
    double basePrice = _getBasePrice();
    double totalPrice = basePrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Icon(Icons.receipt, color: Colors.green[700], size: 24),
              const SizedBox(width: 10),
              Text(
                'Price Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Base Price',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                '\$${basePrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Service Fee',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              Text(
                '\$0.50',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              Text(
                '\$${(totalPrice + 0.50).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTicketCard({
    required String route,
    required String type,
    required String date,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.confirmation_number, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$type • $date',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getBasePrice() {
    switch (_selectedTicketType) {
      case 'Single Journey':
        return 2.50;
      case 'Daily Pass':
        return 8.00;
      case 'Weekly Pass':
        return 35.00;
      case 'Monthly Pass':
        return 120.00;
      default:
        return 2.50;
    }
  }

  void _purchaseTicket() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 30),
              const SizedBox(width: 10),
              const Text('Success!'),
            ],
          ),
          content: Text(
            'Your ticket for $_selectedRoute ($_selectedTicketType) has been purchased successfully!',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Navigate to ticket details or home
              },
              child: Text('OK', style: TextStyle(color: Colors.green[700])),
            ),
          ],
        );
      },
    );
  }
}
