import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static bool _isInitialized = false;

  // Environment variable keys
  static const String _printfulClientIdKey = 'PRINTFUL_CLIENT_ID';
  static const String _printfulSecretKeyKey = 'PRINTFUL_SECRET_KEY';
  static const String _weatherApiKeyKey = 'WEATHER_API_KEY';
  static const String _googleMapsApiKeyKey = 'GOOGLE_MAPS_API_KEY';
  static const String _bokunAccessKeyKey = 'BOKUN_ACCESS_KEY';
  static const String _bokunSecretKeyKey = 'BOKUN_SECRET_KEY';
  static const String _bokunBaseUrlKey = 'BOKUN_BASE_URL';
  static const String _rapydAccessKeyKey = 'RAPYD_ACCESS_KEY';
  static const String _rapydSecretKeyKey = 'RAPYD_SECRET_KEY';
  static const String _firebaseProjectIdKey = 'FIREBASE_PROJECT_ID';

  static String get printfulClientId {
    _checkInitialized();
    return dotenv.env[_printfulClientIdKey] ?? '';
  }

  static String get printfulSecretKey {
    _checkInitialized();
    return dotenv.env[_printfulSecretKeyKey] ?? '';
  }

  static String get weatherApiKey {
    _checkInitialized();
    return dotenv.env[_weatherApiKeyKey] ?? '';
  }

  static String get googleMapsApiKey {
    _checkInitialized();
    return dotenv.env[_googleMapsApiKeyKey] ?? '';
  }

  static String get bokunAccessKey {
    _checkInitialized();
    return dotenv.env[_bokunAccessKeyKey] ?? '';
  }

  static String get bokunSecretKey {
    _checkInitialized();
    return dotenv.env[_bokunSecretKeyKey] ?? '';
  }

  static String get bokunBaseUrl {
    _checkInitialized();
    return dotenv.env[_bokunBaseUrlKey] ?? '';
  }

  static String get rapydAccessKey {
    _checkInitialized();
    return dotenv.env[_rapydAccessKeyKey] ?? '';
  }

  static String get rapydSecretKey {
    _checkInitialized();
    return dotenv.env[_rapydSecretKeyKey] ?? '';
  }

  static String get firebaseProjectId {
    _checkInitialized();
    return dotenv.env[_firebaseProjectIdKey] ?? '';
  }

  static void _checkInitialized() {
    if (!_isInitialized) {
      throw NotInitializedError('ConfigService not initialized. Call ConfigService.initialize() first.');
    }
  }

  static Future<void> initialize() async {
    try {
      // Load environment variables
      await dotenv.load();
      
      // Validate required environment variables
      _validateRequiredEnvVars();
      
      // Set initialization flag
      _isInitialized = true;
    } catch (e) {
      rethrow;
    }
  }

  static void _validateRequiredEnvVars() {
    final requiredVars = [
      _printfulClientIdKey,
      _printfulSecretKeyKey,
      _weatherApiKeyKey,
      _googleMapsApiKeyKey,
      _bokunAccessKeyKey,
      _bokunSecretKeyKey,
      _bokunBaseUrlKey,
      _rapydAccessKeyKey,
      _rapydSecretKeyKey,
      _firebaseProjectIdKey,
    ];

    final missingVars = requiredVars.where((key) => dotenv.env[key] == null || dotenv.env[key]!.isEmpty).toList();
    
    if (missingVars.isNotEmpty) {
      throw NotInitializedError('Missing required environment variables: ${missingVars.join(', ')}');
    }
  }
}

class NotInitializedError extends Error {
  final String message;
  NotInitializedError(this.message);
  
  @override
  String toString() => message;
}