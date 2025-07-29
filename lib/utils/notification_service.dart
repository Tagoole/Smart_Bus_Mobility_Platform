import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize notifications
  Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');

      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _saveTokenToFirebase(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirebase);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    } else {
      print('User declined or has not accepted permission');
    }
  }

  // Save FCM token to Firebase
  Future<void> _saveTokenToFirebase(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      _showLocalNotification(message);
    }
  }

  // Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Handling a background message: ${message.messageId}');

    // Save notification to Firebase for user to see later
    await _saveNotificationToFirebase(message);
  }

  // Handle notification taps
  void _handleNotificationTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');

    // Navigate based on notification type
    if (message.data['type'] == 'booking_confirmation') {
      // Navigate to booking details
      print('Navigate to booking details');
    } else if (message.data['type'] == 'bus_update') {
      // Navigate to bus tracking
      print('Navigate to bus tracking');
    }
  }

  // Show local notification
  void _showLocalNotification(RemoteMessage message) {
    // This would typically use flutter_local_notifications package
    // For now, we'll just print the notification
    print('Local notification: ${message.notification?.title}');
  }

  // Save notification to Firebase
  static Future<void> _saveNotificationToFirebase(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .add({
          'title': message.notification?.title ?? 'Notification',
          'body': message.notification?.body ?? '',
          'data': message.data,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      print('Error saving notification to Firebase: $e');
    }
  }

  // Send booking confirmation notification
  Future<void> sendBookingConfirmation({
    required String userId,
    required String bookingId,
    required String destination,
    required DateTime departureDate,
    required double amount,
  }) async {
    try {
      // Get user's notification settings
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final notificationSettings =
          userData['notificationSettings'] as Map<String, dynamic>? ?? {};

      // Send push notification if enabled
      if (notificationSettings['pushNotifications'] == true) {
        await _sendPushNotification(
          userId: userId,
          title: 'Booking Confirmed!',
          body:
              'Your booking to $destination on ${_formatDate(departureDate)} has been confirmed.',
          data: {
            'type': 'booking_confirmation',
            'bookingId': bookingId,
          },
        );
      }

      // Send email notification if enabled
      if (notificationSettings['emailNotifications'] == true) {
        await _sendEmailNotification(
          email: userData['email'],
          subject: 'Booking Confirmation - Smart Bus Mobility',
          body: _generateEmailBody(
            destination: destination,
            departureDate: departureDate,
            amount: amount,
            bookingId: bookingId,
          ),
        );
      }

      // Send SMS notification if enabled
      if (notificationSettings['smsNotifications'] == true) {
        await _sendSMSNotification(
          phone: userData['contact'],
          message:
              'Your booking to $destination on ${_formatDate(departureDate)} has been confirmed. Amount: UGX ${amount.toStringAsFixed(0)}',
        );
      }

      // Save notification to user's notification history
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Booking Confirmed!',
        'body':
            'Your booking to $destination on ${_formatDate(departureDate)} has been confirmed.',
        'type': 'booking_confirmation',
        'bookingId': bookingId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error sending booking confirmation: $e');
    }
  }

  // Send bus update notification
  Future<void> sendBusUpdateNotification({
    required String userId,
    required String busId,
    required String message,
    required String type, // 'delay', 'arrival', 'departure'
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final notificationSettings =
          userData['notificationSettings'] as Map<String, dynamic>? ?? {};

      if (notificationSettings['pushNotifications'] == true) {
        await _sendPushNotification(
          userId: userId,
          title: 'Bus Update',
          body: message,
          data: {
            'type': 'bus_update',
            'busId': busId,
            'updateType': type,
          },
        );
      }

      // Save to notification history
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': 'Bus Update',
        'body': message,
        'type': 'bus_update',
        'busId': busId,
        'updateType': type,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('Error sending bus update notification: $e');
    }
  }

  // Send push notification via Firebase Cloud Functions
  Future<void> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // This would typically call a Firebase Cloud Function
      // For now, we'll save it to a notifications collection
      await _firestore.collection('push_notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  // Send email notification
  Future<void> _sendEmailNotification({
    required String email,
    required String subject,
    required String body,
  }) async {
    try {
      // This would typically call an email service (SendGrid, Mailgun, etc.)
      // For now, we'll save it to Firebase for processing
      await _firestore.collection('email_notifications').add({
        'to': email,
        'subject': subject,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      print('Error sending email notification: $e');
    }
  }

  // Send SMS notification
  Future<void> _sendSMSNotification({
    required String phone,
    required String message,
  }) async {
    try {
      // This would typically call an SMS service (Twilio, etc.)
      // For now, we'll save it to Firebase for processing
      await _firestore.collection('sms_notifications').add({
        'to': phone,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      print('Error sending SMS notification: $e');
    }
  }

  // Generate email body
  String _generateEmailBody({
    required String destination,
    required DateTime departureDate,
    required double amount,
    required String bookingId,
  }) {
    return '''
Dear Customer,

Your booking has been confirmed successfully!

Booking Details:
- Destination: $destination
- Departure Date: ${_formatDate(departureDate)}
- Amount: UGX ${amount.toStringAsFixed(0)}
- Booking ID: $bookingId

Thank you for choosing Smart Bus Mobility!

Best regards,
Smart Bus Mobility Team
''';
  }

  // Format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Get user notifications
  Stream<QuerySnapshot> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(
      String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  // Delete notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }
}











