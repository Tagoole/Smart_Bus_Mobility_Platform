// this is where the sign up and other methods will live

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> signUpUser({
    required String email,
    required String password,
    required String confirmPassword,
    required String contact,
    required String username,
    required String role,
  }) async {
    try {
      if (email.isNotEmpty &&
          password.isNotEmpty &&
          confirmPassword.isNotEmpty &&
          username.isNotEmpty &&
          contact.isNotEmpty &&
          role.isNotEmpty) {
        if (password != confirmPassword) {
          // saving the user
          UserCredential credential = await _auth
              .createUserWithEmailAndPassword(email: email, password: password);
          print(credential.user!.uid);

          // Adding the user to the database
          await _firestore.collection('users').doc(credential.user!.uid).set({
            'uid': credential.user!.uid,
            'username': username,
            'email': email,
            'role': role,
            'contact': contact,
          });
          return 'Success';
        }
        return 'Passwords donot match..';
      }
    } catch (error) {
      return error.toString();
    }
    return '';
  }
}
