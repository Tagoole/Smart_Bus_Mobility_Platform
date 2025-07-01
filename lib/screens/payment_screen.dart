import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: PaymentScreen(),
    );
  }
}

class PaymentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Options'),
        
        actions: [
          DropdownButton<String>(
            items: [
              DropdownMenuItem(
                child: Text('Manual (Momo/Airtel)'),
                value: 'manual',
              ),
              DropdownMenuItem(
                child: Text('Online (Visa card)'),
                value: 'online',
              ),
            ],
            onChanged: (_) {},
            hint: Text('Manual (Momo/Airtel)'),
          ),
        ],
      ),
      body: Container(
        color: Colors.teal[100],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                    child: Text('MTN'),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text('Airtel'),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Select Your Service Provider'),
              trailing: Icon(Icons.arrow_drop_down, color: Colors.green),
            ),
            ListTile(
              leading: Icon(Icons.edit, color: Colors.green),
              title: Text('Enter amount you are paying'),
              trailing: Icon(Icons.arrow_drop_down, color: Colors.green),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Message should appear on phone for you to put in your PIN',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
        selectedItemColor: Colors.green[600],
      ),
    );
  }
}