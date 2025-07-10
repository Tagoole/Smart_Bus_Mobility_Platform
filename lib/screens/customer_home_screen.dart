import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:async' as async;

class BusTrackingScreen extends StatefulWidget {
  const BusTrackingScreen({super.key});

  @override
  _BusTrackingScreenState createState() => _BusTrackingScreenState();
}

class _BusTrackingScreenState extends State<BusTrackingScreen> {
  int _selectedIndex = 0;
  bool _showActiveJourney = false;
  String? _username;
  bool _isLoadingUser = true;

  // Automatic refresh timer
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchUsername();
    
    // Set up automatic refresh every 2 minutes
    Timer.periodic(Duration(minutes: 2), (timer) {
      if (mounted) {
        _fetchUsername();
        // Add other refresh logic here
      }
    });
    super.initState();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _username = doc.data()!['username'] ?? '';
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _username = '';
          _isLoadingUser = false;
        });
      }
    } else {
      setState(() {
        _username = '';
        _isLoadingUser = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Notifications Section
                    _buildNotifications(),
                    SizedBox(height: 16),
                    // Main Content
                    _showActiveJourney
                        ? _buildActiveJourney()
                        : _buildMainContent(),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _isLoadingUser
                  ? SizedBox(
                      width: 120,
                      height: 20,
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  : Text(
                      '${_getGreeting()}, ${_username ?? ''} 👋',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
              SizedBox(height: 4),
              Text(
                'Where are we heading today?',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text(
                    '24°C, Kampala',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          Spacer(),
          CircleAvatar(
            backgroundColor: Colors.green[700],
            child: Text(
              _username != null && _username!.isNotEmpty
                  ? _username![0].toUpperCase()
                  : '',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifications() {
    return Column(
      children: [
        _buildNotificationItem(
          Icons.warning_amber,
          'Bus #19 on Route 3 is delayed by 8 mins',
          Colors.orange,
        ),
        _buildNotificationItem(
          Icons.info,
          'Route 4 temporarily suspended due to maintenance',
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildNotificationItem(IconData icon, String text, Color color) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          Icon(Icons.close, size: 20, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Trip Planner/Booking CTA
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan Your Journey',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'From',
                            prefixIcon: Icon(Icons.location_on),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'To',
                            prefixIcon: Icon(Icons.flag),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Date & Time',
                      prefixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Plan Trip',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Live Bus Map (placeholder)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              height: 160,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus, size: 40, color: Colors.blue),
                  SizedBox(height: 8),
                  Text(
                    'Live Bus Map',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'See buses near you in real time',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Upcoming Departures
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
          child: Text(
            'Upcoming Departures',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Container(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildDepartureCard('19', 'Ntinda', '5 mins'),
              _buildDepartureCard('23', 'Entebbe', '12 mins'),
              _buildDepartureCard('15', 'Jinja', '8 mins'),
            ],
          ),
        ),
        // Favorites/Saved Routes
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
          child: Text(
            'Saved Routes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Kampala → Ntinda')),
              Chip(label: Text('Kampala → Entebbe')),
              Chip(label: Text('Kampala → Jinja')),
            ],
          ),
        ),
        // Notifications/Alerts
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            color: Colors.orange[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(Icons.warning_amber, color: Colors.orange),
              title: Text('Bus #19 on Route 3 is delayed by 8 mins'),
              trailing: Icon(Icons.close, color: Colors.grey),
              onTap: () {}, // Dismiss or show details
            ),
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDepartureCard(String bus, String to, String eta) {
    return Card(
      margin: const EdgeInsets.only(right: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bus $bus', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('to $to', style: TextStyle(fontSize: 13)),
            SizedBox(height: 8),
            Text(
              eta,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTile(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green[50],
            child: Icon(icon, color: Colors.green[700]),
          ),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActiveJourney() {
    return Column(
      children: [
        // Handle bar
        Container(
          width: 40,
          height: 4,
          margin: EdgeInsets.only(top: 12, bottom: 20),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Active Journey Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Active Journey',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Journey Details
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kampala → Ntinda',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Route 19',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ETA 14 mins',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '3 stops left',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // View Live Map Button
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton(
            onPressed: () {
              // View live map action
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map, size: 20),
                SizedBox(width: 8),
                Text(
                  'View Live Map',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 24),
        // Back to main content
        TextButton(
          onPressed: () {
            setState(() {
              _showActiveJourney = false;
            });
          },
          child: Text(
            'Back to Main',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(height: 32),
      ],
    );
  }
}
