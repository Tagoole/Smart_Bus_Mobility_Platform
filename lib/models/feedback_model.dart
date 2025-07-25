import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String feedbackId;
  final String userId;
  final String message;
  final int rating; // 1 to 5 stars
  final DateTime timestamp;

  FeedbackModel({
    required this.feedbackId,
    required this.userId,
    required this.message,
    required this.rating,
    required this.timestamp,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json, String docId) {
    return FeedbackModel(
      feedbackId: docId,
      userId: json['userId'],
      message: json['message'],
      rating: json['rating'],
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId':userId,
      'message':message,
      'rating':rating,
      'timestamp':timestamp,
    };
  }
}





