import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/models/bus_model.dart';

class BusDriverHomeScreen extends StatefulWidget {
  const BusDriverHomeScreen({Key? key}) : super(key: key);

  @override
  State<BusDriverHomeScreen> createState() => _BusDriverHomeScreenState();
}


class _BusDriverHomeScreenState extends State<BusDriverHomeScreen> {
  // Driver data
  String _driverName = 'Driver';
  String _driverEmail = '';
  BusModel? _driverBus;

  // Statistics
  int _totalPassengers = 0;
  int _completedTrips = 0;
  double _totalEarnings = 0.0;
  bool _isOnline = false;

  // Loading state
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  // Get current user ID
  String? _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  // Load driver data
  Future<void> _loadDriverData() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get driver user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _driverName = userData['name'] ?? userData['username'] ?? 'Driver';
          _driverEmail = userData['email'] ?? '';
          _isOnline = userData['isOnline'] ?? false;
        });
      }

      // Find the bus assigned to this driver
      final busSnapshot = await FirebaseFirestore.instance
          .collection('buses')
          .where('driverId', isEqualTo: _driverEmail)
          .limit(1)
          .get();

      if (busSnapshot.docs.isNotEmpty) {
        final busData = busSnapshot.docs.first.data();
        setState(() {
          _driverBus = BusModel.fromJson(busData, busSnapshot.docs.first.id);
        });

        // Load statistics for this bus
        await _loadBusStatistics(_driverBus!.busId);
      } else {
        // Try to get all buses and check manually for case-insensitive match
        final allBusesSnapshot =
            await FirebaseFirestore.instance.collection('buses').get();

        for (var doc in allBusesSnapshot.docs) {
          final data = doc.data();
          final driverId = data['driverId']?.toString().toLowerCase() ?? '';
          if (driverId == _driverEmail.toLowerCase()) {
            setState(() {
              _driverBus = BusModel.fromJson(data, doc.id);
            });

            // Load statistics for this bus
            await _loadBusStatistics(_driverBus!.busId);
            break;
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading driver data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load bus statistics
  Future<void> _loadBusStatistics(String busId) async {
    try {
      // Get bookings for this bus
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('busId', isEqualTo: busId)
          .get();

      int passengers = 0;
      double earnings = 0.0;

      for (var doc in bookingsSnapshot.docs) {
        final bookingData = doc.data();
        final adultCount = (bookingData['adultCount'] ?? 1) as int;
        final childrenCount = (bookingData['childrenCount'] ?? 0) as int;
        final totalFare = bookingData['totalFare'] ?? 0.0;

        passengers += adultCount + childrenCount;
        earnings +=
            (totalFare is int) ? totalFare.toDouble() : (totalFare as double);
      }

      // Get completed trips count
      final tripsSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('busId', isEqualTo: busId)
          .where('status', isEqualTo: 'completed')
          .get();

      setState(() {
        _totalPassengers = passengers;
        _totalEarnings = earnings;
        _completedTrips = tripsSnapshot.docs.length;
      });
    } catch (e) {
      print('Error loading bus statistics: $e');
    }
  }

  // Toggle online status
  Future<void> _toggleOnlineStatus() async {
    try {
      final userId = _getCurrentUserId();
      if (userId == null) return;

      final newStatus = !_isOnline;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isOnline': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isOnline = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(newStatus ? 'You are now online' : 'You are now offline'),
          backgroundColor: newStatus ? Colors.green : Colors.grey,
        ),
      );
    } catch (e) {
      print('Error toggling online status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Dashboard'),
        backgroundColor: Colors.green,
        actions: [
          Switch(
            value: _isOnline,
            onChanged: (value) {
              _toggleOnlineStatus();
            },
            activeColor: Colors.white,
            activeTrackColor: Colors.green[700],
          ),
          SizedBox(width: 8),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDriverData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Driver info card
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor:
                                        Colors.green.withOpacity(0.2),
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.green,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _driverName,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _driverEmail,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              _isOnline
                                                  ? Icons.circle
                                                  : Icons.circle_outlined,
                                              size: 12,
                                              color: _isOnline
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              _isOnline ? 'Online' : 'Offline',
                                              style: TextStyle(
                                                color: _isOnline
                                                    ? Colors.green
                                                    : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // Bus info card
                      if (_driverBus != null)
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned Bus',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.directions_bus,
                                        color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      _driverBus!.numberPlate,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Route: ${_driverBus!.startPoint} → ${_driverBus!.destination}',
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Seats: ${_driverBus!.seatCapacity}',
                                ),
                                SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Status: '),
                                    Text(
                                      _driverBus!.isAvailable
                                          ? 'Available'
                                          : 'Unavailable',
                                      style: TextStyle(
                                        color: _driverBus!.isAvailable
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                      SizedBox(height: 16),

                      // Statistics cards
                      Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Passengers',
                              _totalPassengers.toString(),
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Trips',
                              _completedTrips.toString(),
                              Icons.route,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _buildStatCard(
                        'Total Earnings',
                        'UGX ${_totalEarnings.toStringAsFixed(0)}',
                        Icons.attach_money,
                        Colors.green,
                      ),

                      SizedBox(height: 24),

                      // Quick actions
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'Start Trip',
                              Icons.play_arrow,
                              Colors.green,
                              () {
                                // Switch to map tab in the NavBarScreen
                                final parentNavBar =
                                    DefaultTabController.of(context);
                                if (parentNavBar != null) {
                                  // If we're already in a NavBarScreen, just switch tabs
                                  parentNavBar
                                      .animateTo(1); // Index 1 is the Map tab
                                } else {
                                  // Otherwise navigate to the NavBarScreen with the Map tab selected
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/driver_navbar',
                                    arguments: 1, // Index for map tab
                                  );
                                }
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              'View Map',
                              Icons.map,
                              Colors.blue,
                              () {
                                // Switch to map tab in the NavBarScreen
                                final parentNavBar =
                                    DefaultTabController.of(context);
                                if (parentNavBar != null) {
                                  // If we're already in a NavBarScreen, just switch tabs
                                  parentNavBar
                                      .animateTo(1); // Index 1 is the Map tab
                                } else {
                                  // Otherwise navigate to the NavBarScreen with the Map tab selected
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/driver_navbar',
                                    arguments: 1, // Index for map tab
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              'View Passengers',
                              Icons.people,
                              Colors.orange,
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Passenger list feature coming soon'),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              'Report Issue',
                              Icons.report_problem,
                              Colors.red,
                              () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Report issue feature coming soon'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Helper method to build stat cards
  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build action buttons
  Widget _buildActionButton(
      String title, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
      ),
      child: Column(
        children: [
          Icon(icon),
          SizedBox(height: 4),
          Text(title),
        ],
      ),
    );
  }
}

