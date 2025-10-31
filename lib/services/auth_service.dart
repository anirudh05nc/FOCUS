// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Get an instance of Firebase Auth
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // SIGN UP a new user with email and password
  Future<User?> signUpWithEmailPassword(String email, String password, String username) async {
    try {
      // This will create the user in Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = result.user;

      if(user != null) {
        // Update the display name in Firebase Auth
        await user.updateDisplayName(username);

        // Create a new document for the user in the 'users' collection
        await _firestore.collection('users').doc(user.uid).set({
          'username': username,
          'email': email,
          'currentStreak': 0,
          'highestStreak': 0,
          'lastSessionDate': null,
          'streakStartDate': null,
        });
      }
      // Return the user object if successful
      return user;
    } on FirebaseAuthException catch (e) {
      // Handle errors (e.g., email already in use, weak password)
      print("Sign Up Error: ${e.message}");
      return null;
    }
  }

  // SIGN IN an existing user with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      // This will sign the user in
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Return the user object if successful
      return result.user;
    } on FirebaseAuthException catch (e) {
      // Handle errors (e.g., wrong password, user not found)
      print("Sign In Error: ${e.message}");
      return null;
    }
  }

  // SIGN OUT the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // AUTH STATE CHANGES stream
  // This is the most important part! It tells your app if a user is logged in or not.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
