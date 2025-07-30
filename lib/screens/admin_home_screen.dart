import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_bus_mobility_platform1/screens/bus_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});


  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Data holders
  Map<String, dynamic> summaryData = {};
  List<Map<String, dynamic>> recentActivities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadDashboardData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    print('Loading dashboard data...');
    try {
      // Load summary data from Firebase
      final usersSnapshot = await _firestore.collection('users').get();
      print('Users fetched: ${usersSnapshot.size}');
      final busesSnapshot = await _firestore.collection('buses').get();
      print('Buses fetched: ${busesSnapshot.size}');
      final bookingsSnapshot = await _firestore.collection('bookings').get();
      print('Bookings fetched: ${bookingsSnapshot.size}');
      // Filter drivers from users
      final usersList = usersSnapshot.docs.map((doc) => doc.data() ?? {}).toList();
      final driversList = usersList.where((user) => (user['role']?.toString().toLowerCase() ?? '') == 'driver').toList();
      // Load recent activities
      final activitiesSnapshot = await _firestore
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(4)
          .get();
      print('Activities fetched: ${activitiesSnapshot.size}');
      setState(() {
        summaryData = {
          'usersCount': usersSnapshot.size ?? 0,
          'usersList': usersList,
          'activeDrivers': driversList.length,
          'driversList': driversList,
          'totalBuses': busesSnapshot.size ?? 0,
          'busesList': busesSnapshot.docs.map((doc) => doc.data() ?? {}).toList(),
          'totalTickets': bookingsSnapshot.size ?? 0,
          'ticketsList': bookingsSnapshot.docs.map((doc) {
            final data = doc.data() ?? {};
            data['bookingId'] = doc.id;
            return data;
          }).toList(),
        };
        recentActivities = activitiesSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'action': data['action'] ?? '',
            'time': _formatTime(data['timestamp']?.toDate() ?? DateTime.now()),
            'status': data['status'] ?? '',
            'user': data['user'] ?? '',
          };
        }).toList();
        isLoading = false;
      });
      print('Dashboard data loaded, isLoading set to false');
    } catch (e, stack) {
      print('Error loading dashboard data: $e');
      print(stack);
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  // Logout function
  Future<void> _handleLogout() async {
    // Show confirmation dialog
    bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
    try {
      await _auth.signOut();
      if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (Route<dynamic> route) => false,
          );
      }
    } catch (e) {
        if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(),
                _buildWelcomeSection(),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(50.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF576238),
                      ),
                    ),
                  )
                else ...[
                  Builder(
                    builder: (context) {
                      try {
                        return _buildSummaryCards();
                      } catch (e, stack) {
                        print('Error building summary cards: $e');
                        print(stack);
                        return Text('Error building summary cards: $e');
                      }
                    },
                  ),
                  Builder(
                    builder: (context) {
                      try {
                        return _buildQuickActions();
                      } catch (e, stack) {
                        print('Error building quick actions: $e');
                        print(stack);
                        return Text('Error building quick actions: $e');
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16), // reduced from 24
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0), // reduced from 24
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8), // reduced from 16
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF576238), Color(0xFF6B7244)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12), // reduced from 16
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF576238).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.explore,
                    color: Colors.white,
                    size: 24, // reduced from 32
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2), // reduced from 4
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD95D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: Color(0xFF576238),
                      size: 10, // reduced from 12
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12), // reduced from 24
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 20, // reduced from 28
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 2), // reduced from 4
                  Text(
                    'Manage your Buses and Drivers',
                          style: TextStyle(
                      fontSize: 12, // reduced from 16
                      color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
                    IconButton(
                      onPressed: _handleLogout,
                      icon: const Icon(
                        Icons.logout,
                        color: Color(0xFF576238),
                size: 20, // reduced from 24
                      ),
                      tooltip: 'Logout',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final width = MediaQuery.of(context).size.width;
    return Container(
      margin: const EdgeInsets.all(12), // reduced from 24
      padding: const EdgeInsets.all(16), // reduced from 32
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, const Color(0xFFF0EADC).withOpacity(0.2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16), // reduced from 24
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6, // reduced from 10
            offset: const Offset(0, 2), // reduced offset
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, Admin! 👋',
                  style: TextStyle(
                    fontSize: 16, // reduced from 24
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 6)
                ,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final int usersCount = summaryData['usersCount'] ?? 0;
    final int driversCount = summaryData['activeDrivers'] ?? 0;
    final int busesCount = summaryData['totalBuses'] ?? 0;
    final int ticketsCount = summaryData['totalTickets'] ?? 0;
    final width = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: GestureDetector(
                onTap: _showUsersDialog,
                child: Card(
                  color: const Color(0xFFFFF9E3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, color: Color(0xFFD4A015), size: 22),
                        const SizedBox(height: 4),
                        Text('$usersCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFD4A015)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 1),
                        const Text('Users', style: TextStyle(fontSize: 10, color: Color(0xFFD4A015)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: GestureDetector(
                onTap: _showDriversDialog,
                child: Card(
                  color: const Color(0xFFE8F5E8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people, color: Color(0xFF576238), size: 22),
                        const SizedBox(height: 4),
                        Text('$driversCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF576238)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 1),
                        const Text('Drivers', style: TextStyle(fontSize: 10, color: Color(0xFF576238)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: GestureDetector(
                onTap: _showBusesDialog,
                child: Card(
                  color: const Color(0xFFEBF8FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_bus, color: Color(0xFF2563EB), size: 22),
                        const SizedBox(height: 4),
                        Text('$busesCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 1),
                        const Text('Buses', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: GestureDetector(
                onTap: _showTicketsDialog,
                child: Card(
                  color: const Color(0xFFECFDF5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.confirmation_number, color: Color(0xFF059669), size: 22),
                        const SizedBox(height: 4),
                        Text('$ticketsCount', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF059669)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 1),
                        const Text('Tickets', style: TextStyle(fontSize: 10, color: Color(0xFF059669)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> item) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.95, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(8), // reduced from 16
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  item['bgColor'].withOpacity(0.35),
                  Colors.white,
                  item['bgColor'].withOpacity(0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12), // reduced from 20
              boxShadow: [
                BoxShadow(
                  color: item['color'].withOpacity(0.18),
                  blurRadius: 10, // reduced from 18
                  spreadRadius: 1, // reduced from 2
                  offset: const Offset(0, 4), // reduced offset
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: item['color'].withOpacity(0.4),
                          blurRadius: 8, // reduced from 18
                          spreadRadius: 1, // reduced from 2
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: item['bgColor'].withOpacity(0.18),
                      radius: 14, // reduced from 22
                      child: Icon(
                        item['icon'],
                        color: item['color'],
                        size: 18, // reduced from 28
                    ),
                  ),
                ),
                ),
                const SizedBox(height: 8), // reduced from 14
                Center(
                  child: Text(
                    item['value'],
                    style: TextStyle(
                      fontSize: 18, // reduced from 28
                      fontWeight: FontWeight.w900,
                      color: item['color'],
                      fontFamily: 'Poppins',
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: item['color'].withOpacity(0.2),
                          blurRadius: 3, // reduced from 6
                          offset: const Offset(0, 1), // reduced offset
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2), // reduced from 4
                Center(
                  child: Text(
                    item['title'],
                    style: const TextStyle(
                      fontSize: 10, // reduced from 14
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item['isIncrease'] ? Icons.trending_up : Icons.trending_down,
                      color: item['isIncrease'] ? Colors.green : Colors.red,
                      size: 10, // reduced from 12
                    ),
                    const SizedBox(width: 2),
                    Text(
                      item['change'],
                      style: TextStyle(
                        fontSize: 8, // reduced from 10
                        fontWeight: FontWeight.w500,
                        color: item['isIncrease'] ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'vs yesterday',
                      style: TextStyle(fontSize: 7, color: Color(0xFF9CA3AF)), // reduced from 8
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    final List<Map<String, dynamic>> quickActions = [
      {
        'title': 'Manage Buses',
        'description': 'Add, edit, or remove buses from your fleet',
        'icon': Icons.directions_bus,
        'color': const Color(0xFF576238),
        'bgColor': const Color(0xFFE8F5E8),
        'action': 'manage-buses',
      }
    ];
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 400 ? 1 : 2;
    return Padding(
      padding: const EdgeInsets.all(12), // reduced from 24
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16, // reduced from 24
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 2), // reduced from 4
              Text(
                'Streamline your workflow with these shortcuts',
                style: TextStyle(
                  fontSize: 12, // reduced from 16
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12), // reduced from 24
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 8, // reduced from 16
              mainAxisSpacing: 8, // reduced from 16
              childAspectRatio: 1.2, // slightly more square
            ),
            itemCount: quickActions.length,
            itemBuilder: (context, index) {
              return _buildQuickActionCard(quickActions[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    return GestureDetector(
      onTap: () => _handleActionClick(action['action']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: action['featured'] == true
              ? Border.all(color: const Color(0xFFFFD95D), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        constraints: const BoxConstraints(
          minHeight: 180,
          maxHeight: 220,
          minWidth: 160,
          maxWidth: 240,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (action['featured'] == true)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: const Row(
                  children: [
                    Icon(
                      Icons.star,
                      color: Color(0xFFFFD95D),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'FEATURED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD4A015),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: action['bgColor'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    action['icon'],
                    color: action['color'],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action['title'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['description'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleActionClick(action['action']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: action['color'],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Get Started',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.amber;
      case 'scheduled':
        return Colors.blue;
      default:
        return Colors.purple;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade50;
      case 'pending':
        return Colors.amber.shade50;
      case 'scheduled':
        return Colors.blue.shade50;
      default:
        return Colors.purple.shade50;
    }
  }

  void _handleActionClick(String action) {
    switch (action) {
      case 'create-route':
        // Navigate to route optimization page
        Navigator.pushNamed(context, '/route-optimization');
        break;
      case 'manage-buses':
        // Navigate to bus management screen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BusManagementScreen()),
        );
        break;
      case 'manage-drivers':
        Navigator.pushNamed(context, '/manage-drivers');
        break;
      case 'view-feedback':
        Navigator.pushNamed(context, '/feedback');
        break;
      case 'view-reports':
        Navigator.pushNamed(context, '/reports');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$action feature coming soon!'),
            backgroundColor: const Color(0xFF576238),
          ),
        );
    }
  }

  void _showDriversDialog() {
    final drivers = (summaryData['driversList'] as List<dynamic>?) ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Drivers'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: drivers.isEmpty
              ? const Center(child: Text('No drivers found.'))
              : ListView.builder(
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index] ?? {};
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(driver['username'] ?? driver['name'] ?? 'No Name'),
                      subtitle: Text(driver['email'] ?? ''),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBusesDialog() {
    final buses = (summaryData['busesList'] as List<dynamic>?) ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Buses'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: buses.isEmpty
              ? const Center(child: Text('No buses found.'))
              : ListView.builder(
                  itemCount: buses.length,
                  itemBuilder: (context, index) {
                    final bus = buses[index] ?? {};
                    return ListTile(
                      leading: const Icon(Icons.directions_bus),
                      title: Text(bus['numberPlate'] ?? 'No Plate'),
                      subtitle: Text(bus['startPoint'] != null && bus['destination'] != null
                          ? '${bus['startPoint']} → ${bus['destination']}'
                          : ''),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTicketsDialog() {
    final tickets = (summaryData['ticketsList'] as List<dynamic>?) ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Tickets'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: tickets.isEmpty
              ? const Center(child: Text('No tickets found.'))
              : ListView.builder(
                  itemCount: tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = tickets[index] ?? {};
                    return ListTile(
                      leading: const Icon(Icons.confirmation_number),
                      title: Text(ticket['bookingId'] ?? 'No ID'),
                      subtitle: Text(ticket['userEmail'] ?? ''),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUsersDialog() {
    final users = (summaryData['usersList'] as List<dynamic>?) ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Users'),
        content: SizedBox(
          width: 300,
          height: 400,
          child: users.isEmpty
              ? const Center(child: Text('No users found.'))
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index] ?? {};
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(user['username'] ?? 'No Name'),
                      subtitle: Text(user['email'] ?? ''),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}




