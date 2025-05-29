import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class CloudCoverService {
  // TODO: Move to secure storage
  static const String _apiKey = 'b7889cba97489be6e2f825f3861feb23';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  static Future<Map<String, dynamic>> getCloudCoverData(Position position) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric'
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'cloudCover': data['clouds']['all'] ?? 0, // Cloud coverage percentage
          'temperature': data['main']['temp'] ?? 0,
          'humidity': data['main']['humidity'] ?? 0,
          'windSpeed': data['wind']['speed'] ?? 0,
          'description': data['weather'][0]['description'] ?? '',
          'icon': data['weather'][0]['icon'] ?? '',
        };
      } else {
        throw Exception('Failed to load cloud cover data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching cloud cover data: $e');
      rethrow;
    }
  }

  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Get current position
    return await Geolocator.getCurrentPosition();
  }
} 