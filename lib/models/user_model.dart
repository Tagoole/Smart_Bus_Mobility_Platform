import 'dart:typed_data';

class UserModel {
  final String username;
  final String email;
  final String contact;
  final String role;
  Uint8List? profilePicture;

  UserModel({
    required this.username,
    required this.email,
    required this.contact,
    required this.role,
    this.profilePicture,
  });
}
