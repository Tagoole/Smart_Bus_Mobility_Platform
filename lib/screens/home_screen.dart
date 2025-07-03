import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const BusBuddyApp());
}

class BusBuddyApp extends StatelessWidget {
  const BusBuddyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bus Buddy',
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF576238), // Dark Olive Green
        scaffoldBackgroundColor: const Color(0xFFF0EADC), // Light Cream
        fontFamily: 'Inter',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF576238),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EADC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const HeaderWidget(),
            const NotificationBanner(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: const [
                    MapPreviewWidget(),
                    QuickActionsWidget(),
                    ActiveJourneyWidget(hasActiveJourney: true),
                    SizedBox(height: 100), // Space for bottom navigation
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavigationWidget(),
    );
  }
}

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({Key? key}) : super(key: key);

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning";
    if (hour < 18) return "Good afternoon";
    return "Good evening";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${getGreeting()}, Larry 👋",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Where are we heading today?",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Text("🌤️", style: TextStyle(fontSize: 14)),
                    SizedBox(width: 8),
                    Text(
                      "24°C, Kampala",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_outlined),
                    iconSize: 24,
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFD95D),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF576238).withOpacity(0.2),
                child: const Text(
                  "LM",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF576238),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NotificationBanner extends StatefulWidget {
  const NotificationBanner({Key? key}) : super(key: key);

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner> {
  List<NotificationItem> notifications = [
    NotificationItem(
      id: "1",
      type: NotificationType.warning,
      message: "Bus #19 on Route 3 is delayed by 8 mins",
    ),
    NotificationItem(
      id: "2",
      type: NotificationType.info,
      message: "Route 4 temporarily suspended due to maintenance",
    ),
  ];

  void dismissNotification(String id) {
    setState(() {
      notifications.removeWhere((n) => n.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: notifications.map((notification) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: notification.type == NotificationType.warning
                  ? const Color(0xFFFFD95D).withOpacity(0.1)
                  : const Color(0xFF576238).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: notification.type == NotificationType.warning
                      ? const Color(0xFFFFD95D)
                      : const Color(0xFF576238),
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  notification.type == NotificationType.warning
                      ? Icons.warning_amber_outlined
                      : Icons.info_outline,
                  color: notification.type == NotificationType.warning
                      ? const Color(0xFFFFD95D)
                      : const Color(0xFF576238),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    notification.message,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                IconButton(
                  onPressed: () => dismissNotification(notification.id),
                  icon: const Icon(Icons.close, size: 20),
                  splashRadius: 20,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MapPreviewWidget extends StatelessWidget {
  const MapPreviewWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Map Preview
          Container(
            height: 200,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              ),
            ),
            child: Stack(
              children: [
                // Location indicator
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Color(0xFF576238),
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Bugolobi Stage",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Live tracking button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text("Live Tracking"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD95D),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bus information
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Next Buses",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBusInfo("12", "Route 12 - City Center", "4 mins", true),
                const SizedBox(height: 8),
                _buildBusInfo("19", "Route 19 - Ntinda", "9 mins", false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusInfo(String route, String destination, String time, bool isNext) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isNext ? const Color(0xFF576238) : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              route,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isNext ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            destination,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isNext ? const Color(0xFF576238) : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class QuickActionsWidget extends StatelessWidget {
  const QuickActionsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final actions = [
      QuickAction(
        icon: Icons.map_outlined,
        title: "Plan Journey",
        description: "Find best route",
      ),
      QuickAction(
        icon: Icons.confirmation_number_outlined,
        title: "Buy Ticket",
        description: "Quick purchase",
      ),
      QuickAction(
        icon: Icons.directions_bus_outlined,
        title: "Track My Bus",
        description: "Live location",
      ),
      QuickAction(
        icon: Icons.receipt_long_outlined,
        title: "My Tickets",
        description: "View history",
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        action.icon,
                        size: 32,
                        color: const Color(0xFF576238),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        action.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        action.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ActiveJourneyWidget extends StatelessWidget {
  final bool hasActiveJourney;

  const ActiveJourneyWidget({Key? key, this.hasActiveJourney = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: hasActiveJourney ? const Color(0xFF576238) : Colors.grey.shade300,
            width: 4,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: hasActiveJourney ? _buildActiveJourney() : _buildNoActiveJourney(),
      ),
    );
  }

  Widget _buildActiveJourney() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Active Journey",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF576238).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF576238),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    "Live",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF576238),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Icon(
              Icons.location_on,
              size: 20,
              color: Color(0xFF576238),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Kampala → Ntinda",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  "Route 19",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Row(
                children: const [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Color(0xFFFFD95D),
                  ),
                  SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ETA 14 mins",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        "3 stops left",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.navigation, size: 16),
              label: const Text("View Live Map"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD95D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoActiveJourney() {
    return Column(
      children: [
        Icon(
          Icons.directions_bus_outlined,
          size: 48,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 12),
        Text(
          "No active trip",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD95D),
              foregroundColor: Colors.black,
            ),
            child: const Text("Plan a Trip"),
          ),
        ),
      ],
    );
  }
}

class BottomNavigationWidget extends StatefulWidget {
  const BottomNavigationWidget({Key? key}) : super(key: key);

  @override
  State<BottomNavigationWidget> createState() => _BottomNavigationWidgetState();
}

class _BottomNavigationWidgetState extends State<BottomNavigationWidget> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, "Home"),
              _buildNavItem(1, Icons.map_outlined, Icons.map, "Plan"),
              _buildNavItem(2, Icons.confirmation_number_outlined, Icons.confirmation_number, "Tickets"),
              _buildNavItem(3, Icons.person_outline, Icons.person, "Profile"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF576238).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              size: 24,
              color: isActive ? const Color(0xFF576238) : Colors.grey.shade600,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? const Color(0xFF576238) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data Models
class NotificationItem {
  final String id;
  final NotificationType type;
  final String message;

  NotificationItem({
    required this.id,
    required this.type,
    required this.message,
  });
}

enum NotificationType { info, warning }

class QuickAction {
  final IconData icon;
  final String title;
  final String description;

  QuickAction({
    required this.icon,
    required this.title,
    required this.description,
  });
}