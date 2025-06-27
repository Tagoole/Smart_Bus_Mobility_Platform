import 'dart:typed_data';

class UserModel {
  final String username;
  final String email;
  final String phoneNumber;
  final String role;
  Uint8List? profilePicture;

  UserModel({
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.profilePicture,
  });
}
