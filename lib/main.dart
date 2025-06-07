// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/firebase_service.dart';
import 'screens/home_screen.dart';
import 'services/config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔑 Load environment variables FIRST
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded successfully');

    // Validate required environment variables
    _validateEnvironmentVariables();

  } catch (e) {
    print('❌ CRITICAL ERROR: Could not load .env file: $e');
    print('📋 Make sure you have a .env file in your project root with all required keys');
    print('📄 Copy .env.example to .env and fill in your API keys');

    // Show error dialog and don't continue without environment variables
    runApp(_ErrorApp(error: 'Environment configuration missing. Please check your .env file.'));
    return;
  }

  bool firebaseInitialized = false;
  bool supabaseInitialized = false;

  try {
    // Initialize ConfigService first
    await ConfigService.initialize();
    print('✅ ConfigService initialized successfully');

    // Initialize Supabase with environment variables
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL']!;
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

      print('🗄️ Initializing Supabase...');
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      print('✅ Supabase initialized successfully');
      supabaseInitialized = true;
    } catch (supabaseError) {
      print('❌ Error initializing Supabase: $supabaseError');
      // Continue app execution even if Supabase fails
    }

    // Initialize Firebase with environment variables
    try {
      final firebaseApiKey = dotenv.env['FIREBASE_API_KEY']!;
      final firebaseAppId = dotenv.env['FIREBASE_APP_ID']!;
      final firebaseMessagingSenderId = dotenv.env['FIREBASE_MESSAGING_SENDER_ID']!;
      final firebaseProjectId = dotenv.env['FIREBASE_PROJECT_ID']!;
      final firebaseStorageBucket = dotenv.env['FIREBASE_STORAGE_BUCKET']!;

      print('🔥 Initializing Firebase...');
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: firebaseApiKey,
          appId: firebaseAppId,
          messagingSenderId: firebaseMessagingSenderId,
          projectId: firebaseProjectId,
          storageBucket: firebaseStorageBucket,
        ),
      );
      print('✅ Firebase initialized successfully');
      firebaseInitialized = true;

      // Initialize your Firebase service
      await FirebaseService.initialize();
      print('✅ FirebaseService initialized successfully');
    } catch (firebaseError) {
      print('❌ Error initializing Firebase: $firebaseError');
      // Continue app execution even if Firebase fails
    }

  } catch (e) {
    print('❌ Error during initialization: $e');
    // Show error but continue with limited functionality
  }

  print('🚀 Starting Aurora Viking App...');
  print('   Firebase: ${firebaseInitialized ? "✅" : "❌"}');
  print('   Supabase: ${supabaseInitialized ? "✅" : "❌"}');

  runApp(MyApp(
    firebaseInitialized: firebaseInitialized,
    supabaseInitialized: supabaseInitialized,
  ));
}

/// Validates that all required environment variables are present
void _validateEnvironmentVariables() {
  final requiredKeys = [
    'GOOGLE_MAPS_API_KEY',
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_STORAGE_BUCKET',
  ];

  final missingKeys = <String>[];
  final emptyKeys = <String>[];

  for (String key in requiredKeys) {
    final value = dotenv.env[key];
    if (value == null) {
      missingKeys.add(key);
    } else if (value.isEmpty || value.contains('your_') || value.contains('_here')) {
      emptyKeys.add(key);
    }
  }

  if (missingKeys.isNotEmpty) {
    print('❌ MISSING ENVIRONMENT VARIABLES:');
    for (String key in missingKeys) {
      print('   • $key');
    }
  }

  if (emptyKeys.isNotEmpty) {
    print('⚠️ PLACEHOLDER VALUES DETECTED:');
    for (String key in emptyKeys) {
      print('   • $key: "${dotenv.env[key]}"');
    }
  }

  if (missingKeys.isNotEmpty || emptyKeys.isNotEmpty) {
    print('📋 Please update your .env file with real API keys');
    print('📄 Copy .env.example to .env and fill in your values');
    throw Exception('Environment variables not properly configured');
  }

  print('✅ All required environment variables are present and valid');

  // Debug info (remove in production)
  print('🔧 Environment loaded:');
  for (String key in requiredKeys) {
    final value = dotenv.env[key]!;
    final masked = value.length > 10
        ? '${value.substring(0, 6)}...${value.substring(value.length - 4)}'
        : '***';
    print('   $key: $masked');
  }
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
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        colorScheme: ColorScheme.light(
          primary: Colors.tealAccent,
          secondary: Colors.cyanAccent,
          background: Colors.white,
          surface: Colors.white,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.tealAccent,
          elevation: 2,
        ),
        cardTheme: CardTheme(
          color: Colors.white10,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        colorScheme: ColorScheme.dark(
          primary: Colors.tealAccent,
          secondary: Colors.cyanAccent,
          background: Colors.black,
          surface: Colors.black,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)]),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)]),
        ),
        iconTheme: const IconThemeData(color: Colors.tealAccent),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.tealAccent,
          foregroundColor: Colors.black,
        ),
      ),
      themeMode: ThemeMode.system,
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Error app to show when environment variables are missing
class _ErrorApp extends StatelessWidget {
  final String error;

  const _ErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aurora Viking - Configuration Error',
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        appBar: AppBar(
          title: const Text('Configuration Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade700,
                ),
                const SizedBox(height: 20),
                Text(
                  'Configuration Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'Steps to fix:\n'
                        '1. Copy .env.example to .env\n'
                        '2. Fill in your API keys\n'
                        '3. Restart the app',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // You could add a retry mechanism here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Check Documentation'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}