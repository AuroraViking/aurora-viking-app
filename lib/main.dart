// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
// Add your other imports here

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('Firebase initialized successfully');

    // Initialize your Firebase service
    await FirebaseService.initialize();
    print('FirebaseService initialized successfully');

  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aurora Viking App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}