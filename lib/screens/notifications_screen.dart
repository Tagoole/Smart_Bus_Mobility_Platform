import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_bus_mobility_platform1/utils/theme_provider.dart';
import 'package:smart_bus_mobility_platform1/utils/notification_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor:
            isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor:
              isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFF007AFF),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'Please log in to view notifications',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor:
            isDarkMode ? const Color(0xFF1F1F1F) : const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.getUserNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? Colors.white : const Color(0xFF007AFF),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see notifications about your bookings here',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification =
                  notifications[index].data() as Map<String, dynamic>;
              final isRead = notification['read'] ?? false;
              final timestamp = notification['timestamp'] as Timestamp?;
              final title = notification['title'] ?? 'Notification';
              final body = notification['body'] ?? '';
              final type = notification['type'] ?? 'general';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isRead
                        ? (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!)
                        : const Color(0xFF007AFF),
                    width: isRead ? 1 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: _getNotificationColor(type, isDarkMode),
                    child: Icon(
                      _getNotificationIcon(type),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        body,
                        style: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        timestamp != null
                            ? DateFormat('MMM dd, yyyy - HH:mm')
                                .format(timestamp.toDate())
                            : 'Just now',
                        style: TextStyle(
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onSelected: (value) async {
                      if (value == 'mark_read' && !isRead) {
                        await _notificationService.markNotificationAsRead(
                          user.uid,
                          notifications[index].id,
                        );
                      } else if (value == 'delete') {
                        await _notificationService.deleteNotification(
                          user.uid,
                          notifications[index].id,
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isRead)
                        const PopupMenuItem(
                          value: 'mark_read',
                          child: Row(
                            children: [
                              Icon(Icons.check, size: 18),
                              SizedBox(width: 8),
                              Text('Mark as read'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!isRead) {
                      await _notificationService.markNotificationAsRead(
                        user.uid,
                        notifications[index].id,
                      );
                    }
                    // Handle notification tap based on type
                    _handleNotificationTap(notification);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getNotificationColor(String type, bool isDarkMode) {
    switch (type) {
      case 'booking_confirmation':
        return Colors.green;
      case 'bus_update':
        return Colors.blue;
      case 'payment':
        return Colors.orange;
      case 'general':
      default:
        return isDarkMode ? Colors.grey[600]! : Colors.grey[500]!;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'booking_confirmation':
        return Icons.confirmation_number;
      case 'bus_update':
        return Icons.directions_bus;
      case 'payment':
        return Icons.payment;
      case 'general':
      default:
        return Icons.notifications;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'] ?? 'general';

    switch (type) {
      case 'booking_confirmation':
        // Navigate to booking details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigate to booking details'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      case 'bus_update':
        // Navigate to bus tracking
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Navigate to bus tracking'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
      default:
        // Show notification details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(notification['title'] ?? 'Notification'),
            content: Text(notification['body'] ?? ''),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
    }
  }
}


