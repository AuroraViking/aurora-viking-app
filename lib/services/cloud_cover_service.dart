import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'config_service.dart';

class CloudCoverService {
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  static Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<Map<String, dynamic>> getCloudCoverData(Position position) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/weather?lat=${position.latitude}&lon=${position.longitude}&appid=${ConfigService.weatherApiKey}&units=metric'
        ),
      );

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
} 