class ConfigService {
  static bool _isInitialized = false;

  // Hardcoded configuration values
  static const String _printfulClientId = 'app-4877017';
  static const String _printfulSecretKey = 'yzocP5ZiII8NexnxANU3iSALoFijvwnWiVKSzAQ8ErspAbyKMFbDqfSiycl7uOUP';
  static const String _weatherApiKey = 'your_weather_api_key';

  static String get printfulClientId {
    _checkInitialized();
    return _printfulClientId;
  }

  static String get printfulSecretKey {
    _checkInitialized();
    return _printfulSecretKey;
  }

  static String get weatherApiKey {
    _checkInitialized();
    return _weatherApiKey;
  }

  static void _checkInitialized() {
    if (!_isInitialized) {
      throw NotInitializedError('ConfigService not initialized. Call ConfigService.initialize() first.');
    }
  }

  static Future<void> initialize() async {
    try {
      // Set initialization flag
      _isInitialized = true;
      print('ConfigService initialized successfully');
    } catch (e) {
      print('Error initializing ConfigService: $e');
      rethrow;
    }
  }
}

class NotInitializedError extends Error {
  final String message;
  NotInitializedError(this.message);
  
  @override
  String toString() => message;
} 