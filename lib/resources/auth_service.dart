// this is where the sign up and other methods will live
import 'package:smart_bus_mobility_platform1/models/user_model.dart' as model;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  Future<Map<String, String>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'status': 'Google sign in aborted'};
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      // Optionally, add user to Firestore if new
      final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'role': 'user',
          'username': userCredential.user!.displayName ?? '',
          'contact': '',
        });
      }
      return {'status': 'Success', 'role': 'user', 'uid': userCredential.user!.uid};
    } catch (e) {
      return {'status': e.toString()};
    }
  }

  Future<Map<String, String>> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final OAuthCredential facebookAuthCredential = FacebookAuthProvider.credential(result.accessToken!.token);
        UserCredential userCredential = await _auth.signInWithCredential(facebookAuthCredential);
        // Optionally, add user to Firestore if new
        final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'email': userCredential.user!.email,
            'role': 'user',
            'username': userCredential.user!.displayName ?? '',
            'contact': '',
          });
        }
        return {'status': 'Success', 'role': 'user', 'uid': userCredential.user!.uid};
      } else {
        return {'status': result.message ?? 'Facebook sign in failed'};
      }
    } catch (e) {
      return {'status': e.toString()};
    }
  }

  Future<void> signInWithInstagram() async {
    // Instagram login is not natively supported by Firebase Auth.
    // This will open the Instagram login page in a browser as a placeholder.
    const instagramAuthUrl = 'https://www.instagram.com/accounts/login/';
    if (await canLaunch(instagramAuthUrl)) {
      await launch(instagramAuthUrl);
    } else {
      throw 'Could not launch Instagram login';
    }
  }
}















