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
    try {
      // Load summary data from Firebase
      final driversSnapshot = await _firestore.collection('drivers').get();
      final busesSnapshot = await _firestore.collection('buses').get();
      final routesSnapshot = await _firestore
          .collection('routes')
          .where('status', isEqualTo: 'pending')
          .get();
      final feedbackSnapshot = await _firestore.collection('feedback').get();

      // Get today's tickets
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final ticketsSnapshot = await _firestore
          .collection('tickets')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .get();

      // Load recent activities
      final activitiesSnapshot = await _firestore
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(4)
          .get();

      setState(() {
        summaryData = {
          'activeDrivers': driversSnapshot.docs
              .where((doc) => doc.data()['status'] == 'active')
              .length,
          'pendingRoutes': routesSnapshot.size,
          'feedbackCount': feedbackSnapshot.size,
          'totalBuses': busesSnapshot.size,
          'ticketsToday': ticketsSnapshot.size,
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
    } catch (e) {
      print('Error loading dashboard data: $e');
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
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/sign-in', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                  _buildSummaryCards(),
                  _buildQuickActions(),
                  _buildRecentActivity(),
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
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        //Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF576238), Color(0xFF6B7244)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF576238).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.explore,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFD95D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.trending_up,
                      color: Color(0xFF576238),
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage your routes and operations efficiently',
                    style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Last updated',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                        const Text(
                          '2 minutes ago',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedBuilder(
                            animation: _animationController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 0.8 + (0.2 * _animationController.value),
                                child: child,
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green.shade400,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: _handleLogout,
                      icon: const Icon(
                        Icons.logout,
                        color: Color(0xFF576238),
                        size: 24,
                      ),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, const Color(0xFFF0EADC).withValues(alpha: 0.2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, Admin! 👋',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Your system is running smoothly. Here\'s today\'s overview.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD95D).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Text(
                  '98.5%',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF576238),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'System Health',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final List<Map<String, dynamic>> summaryItems = [
      {
        'title': 'Active Drivers',
        'value': '${summaryData['activeDrivers'] ?? 0}',
        'change': '+2',
        'isIncrease': true,
        'icon': Icons.people,
        'color': const Color(0xFF576238),
        'bgColor': const Color(0xFFE8F5E8),
      },
      {
        'title': 'Pending Routes',
        'value': '${summaryData['pendingRoutes'] ?? 0}',
        'change': '-3',
        'isIncrease': false,
        'icon': Icons.location_on,
        'color': const Color(0xFFD4A015),
        'bgColor': const Color(0xFFFFFBEB),
      },
      {
        'title': 'Feedback Count',
        'value': '${summaryData['feedbackCount'] ?? 0}',
        'change': '+12',
        'isIncrease': true,
        'icon': Icons.chat_bubble,
        'color': const Color(0xFF7C3AED),
        'bgColor': const Color(0xFFF3E8FF),
      },
      {
        'title': 'Total Buses',
        'value': '${summaryData['totalBuses'] ?? 0}',
        'change': '+1',
        'isIncrease': true,
        'icon': Icons.directions_bus,
        'color': const Color(0xFF2563EB),
        'bgColor': const Color(0xFFEBF8FF),
      },
      {
        'title': 'Tickets Today',
        'value': '${summaryData['ticketsToday'] ?? 0}',
        'change': '+45',
        'isIncrease': true,
        'icon': Icons.confirmation_number,
        'color': const Color(0xFF059669),
        'bgColor': const Color(0xFFECFDF5),
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Key Metrics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: summaryItems.length,
              itemBuilder: (context, index) {
                final item = summaryItems[index];
                return Container(
                  width: 160,
                  margin: EdgeInsets.only(
                    right: index < summaryItems.length - 1 ? 16 : 0,
                  ),
                  child: _buildSummaryCard(item),
                );
              },
            ),
          ),
        ],
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  item['bgColor'].withValues(alpha: 0.35),
                  Colors.white,
                  item['bgColor'].withValues(alpha: 0.15),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: item['color'].withValues(alpha: 0.18),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with glow
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: item['color'].withValues(alpha: 0.4),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: item['bgColor'].withValues(alpha: 0.18),
                      radius: 18,
                      child: Icon(item['icon'], color: item['color'], size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Value with playful font and color
                Center(
                  child: Text(
                    item['value'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: item['color'],
                      fontFamily: 'Poppins',
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: item['color'].withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Title
                Center(
                  child: Text(
                    item['title'],
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                // Animated progress bar (for demo, random progress)
                TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0.0,
                    end: 0.7 + (item['value'].hashCode % 30) / 100,
                  ),
                  duration: const Duration(milliseconds: 900),
                  builder: (context, progress, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: item['color'].withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          item['color'],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item['isIncrease']
                          ? Icons.trending_up
                          : Icons.trending_down,
                      color: item['isIncrease'] ? Colors.green : Colors.red,
                      size: 12,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      item['change'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: item['isIncrease'] ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'vs yesterday',
                      style: TextStyle(fontSize: 8, color: Color(0xFF9CA3AF)),
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
      },
      {
        'title': 'Manage Drivers',
        'description': 'View and manage driver assignments',
        'icon': Icons.people,
        'color': const Color(0xFF2563EB),
        'bgColor': const Color(0xFFEBF8FF),
        'action': 'manage-drivers',
      },
      {
        'title': 'Create Optimized Route',
        'description': 'Generate the most efficient routes using AI',
        'icon': Icons.location_on,
        'color': const Color(0xFFD4A015),
        'bgColor': const Color(0xFFFFFBEB),
        'action': 'create-route',
        'featured': true,
      },
      {
        'title': 'View Feedback',
        'description': 'Review passenger feedback and ratings',
        'icon': Icons.chat_bubble,
        'color': const Color(0xFF7C3AED),
        'bgColor': const Color(0xFFF3E8FF),
        'action': 'view-feedback',
      },
      {
        'title': 'Analytics & Reports',
        'description': 'Access detailed analytics and insights',
        'icon': Icons.bar_chart,
        'color': const Color(0xFF059669),
        'bgColor': const Color(0xFFECFDF5),
        'action': 'view-reports',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Streamline your workflow with these shortcuts',
                style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
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
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
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
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (action['featured'] == true)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: const Color(0xFFFFD95D),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
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
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action['description'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
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
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full activity view
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: Color(0xFF576238),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: recentActivities.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, dynamic> activity = entry.value;
                bool isLast = index == recentActivities.length - 1;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: !isLast
                        ? const Border(
                            bottom: BorderSide(
                              color: Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _getStatusColor(activity['status']),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity['action'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  activity['time'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                const Text(
                                  ' • ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                                Text(
                                  activity['user'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusBgColor(activity['status']),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          activity['status'],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(activity['status']),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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
}
.
