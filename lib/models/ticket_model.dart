import 'package:cloud_firestore/cloud_firestore.dart';

class TicketModel {
  final String ticketId;
  final String userId;
  final String busId;
  final String routeId;
  final DateTime dateTime;
  final double price;
  final bool isPaid;

  TicketModel({
    required this.ticketId,
    required this.userId,
    required this.busId,
    required this.routeId,
    required this.dateTime,
    required this.price,
    required this.isPaid,
  });

  // Create TicketModel from Firestore document
  factory TicketModel.fromJson(Map<String, dynamic> json, String docId) {
    return TicketModel(
      ticketId: docId,
      userId: json['userId'],
      busId: json['busId'],
      routeId: json['routeId'],
      dateTime: (json['dateTime'] as Timestamp).toDate(),
      price: (json['price'] as num).toDouble(),
      isPaid: json['isPaid'],
    );
  }

  // Convert TicketModel to Firestore-compatible JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'busId': busId,
      'routeId': routeId,
      'dateTime': dateTime,
      'price': price,
      'isPaid': isPaid,
    };
  }
}









