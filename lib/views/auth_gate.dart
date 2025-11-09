import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:focus/views/pages/welcome_page.dart';
import 'package:focus/views/widget_tree.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show a loading indicator while checking the auth state.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // If a user is logged in, show the main app.
        if (snapshot.hasData) {
          return WidgetTree(user: snapshot.data!);
        }

        // If no user is logged in, show the welcome page.
        return const WelcomePage();
      },
    );
  }
}
