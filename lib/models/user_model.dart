import 'dart:typed_data';

class UserModel {
  final String username;
  final String email;
  final String contact;
  final String uid;
  final String role;
  Uint8List? profilePicture;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool smsNotifications;

  UserModel({
    required this.username,
    required this.uid,
    required this.email,
    required this.contact,
    required this.role,
    this.profilePicture,
    this.pushNotifications = true,
    this.emailNotifications = false,
    this.smsNotifications = false,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'uid': uid,
    'email': email,
    'contact': contact,
    'role': role,
    'pushNotifications': pushNotifications,
    'emailNotifications': emailNotifications,
    'smsNotifications': smsNotifications,
  };
}







