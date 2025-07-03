import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: PaymentScreen());
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
        color: const Color.fromARGB(255, 42, 87, 15),
    
          height: 1000, // Set your desired height here
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8.0,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manual Payment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal[900],
                        ),
                      ),
                      SizedBox(height: 16.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow[700],
                            ),
                            child: Text('MTN'),
                          ),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: Text('Airtel'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.0),
                      // First card button
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        color: Colors.transparent,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text('Select Your Service Provider'),
                                  content: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Enter service provider',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Select Your Service Provider',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                              ),
                              Spacer(),
                              Icon(Icons.arrow_drop_down, color: Colors.green),
                            ],
                          ),
                        ),
                      ),
                      // Second card button
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        color: Colors.transparent,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                            alignment: Alignment.centerLeft,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: Text('Enter amount you are paying'),
                                  content: TextField(
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      hintText: 'Enter amount',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.green),
                              SizedBox(width: 8),
                              Text(
                                'Enter amount you are paying',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                              ),
                              Spacer(),
                              Icon(Icons.arrow_drop_down, color: Colors.green),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
