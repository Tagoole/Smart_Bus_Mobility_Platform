// this is where the sign up and other methods will live
import 'package:smart_bus_mobility_platform1/models/user_model.dart' as model;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> signUpUser({
    required String email,
    required String password,
    required String contact,
    required String username,
    required String role,
  }) async {
    try {
      if (email.isNotEmpty &&
          password.isNotEmpty &&
          username.isNotEmpty &&
          contact.isNotEmpty &&
          role.isNotEmpty) {
        // saving the user
        UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print(credential.user!.uid);
        print(credential.user!.email);

        model.UserModel user = model.UserModel(
          username: username,
          uid: credential.user!.uid,
          email: email,
          contact: contact,
          role: role,
        );
        // Adding the user to the database
        await _firestore.collection('users').doc(credential.user!.uid).set(
          user.toJson()
        );
        return 'Success';
      }
    } catch (error) {
      return error.toString();
    }
    return '';
  }

  Future<Map<String, String>> loginUser({
    required String password,
    required String email,
  }) async {
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        UserCredential credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .get();
        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          String userRole = userData['role'] ?? '';

          return {
            'status': 'Success',
            'role': userRole,
            'uid': credential.user!.uid,
          };
        } else {
          return {'status': 'User data not found'};
        }
      } else {
        return {'status': 'Enter all fields'};
      }
    } catch (error) {
      return {'status': error.toString()};
    }
  }
}
