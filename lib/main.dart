// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'services/config_service.dart';
// Add your other imports here

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseInitialized = false;
  bool supabaseInitialized = false;

  try {
    // Initialize ConfigService first
    await ConfigService.initialize();
    print('ConfigService initialized successfully');

    // Initialize Supabase
    try {
      await Supabase.initialize(
        url: 'https://mbbmukqjjdlhhhrtimuv.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1iYm11a3FqamRsaGhocnRpbXV2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkwMjkxMDQsImV4cCI6MjA2NDYwNTEwNH0.Q9bwgZU_XmuxZLbrBsa8PbL8x9NYdoNP17U3UcceM8g',
      );
      print('Supabase initialized successfully');
      supabaseInitialized = true;
    } catch (supabaseError) {
      print('Error initializing Supabase: $supabaseError');
      // Continue app execution even if Supabase fails
    }

    // Initialize Firebase with error handling
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyArCh7e0p46r-ltBRuV08vYxha0eo7DOZo',
          appId: '1:1099021548072:android:abdcb84b6defa64100d31d',
          messagingSenderId: '1099021548072',
          projectId: 'aurora-viking-app',
          storageBucket: 'aurora-viking-app.firebasestorage.app',
        ),
      );
      print('Firebase initialized successfully');
      firebaseInitialized = true;

      // Initialize your Firebase service
      await FirebaseService.initialize();
      print('FirebaseService initialized successfully');
    } catch (firebaseError) {
      print('Error initializing Firebase: $firebaseError');
      // Continue app execution even if Firebase fails
    }

  } catch (e) {
    print('Error during initialization: $e');
    // You might want to show an error dialog here
  }

  runApp(MyApp(
    firebaseInitialized: firebaseInitialized,
    supabaseInitialized: supabaseInitialized,
  ));
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;
  final bool supabaseInitialized;

  const MyApp({
    super.key,
    required this.firebaseInitialized,
    required this.supabaseInitialized,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aurora Viking App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: _getHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  Widget _getHomeScreen() {
    if (supabaseInitialized) {
      // Supabase is working - use it for aurora data
      return const HomeScreen();
    } else if (firebaseInitialized) {
      // Fall back to Firebase if Supabase fails
      return const HomeScreen();
    } else {
      // Both failed
      return const Scaffold(
        body: Center(
          child: Text(
            'Unable to initialize app services.\nPlease check your internet connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }
}