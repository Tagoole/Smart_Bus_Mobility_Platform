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
}
