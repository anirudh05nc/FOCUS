// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:focus/views/auth_gate.dart';
import 'package:focus/views/pages/login_page.dart';
import 'package:focus/views/pages/signup_page.dart';
import 'package:focus/views/pages/welcome_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Focus App',
      theme: ThemeData(
          fontFamily: 'GoogleSans'

      ),
      routes: {
        '/welcome' : (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
      },

      home: const AuthGate(),
    );
  }
}
