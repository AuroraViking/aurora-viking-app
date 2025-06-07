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
    final apiKey = ConfigService.weatherApiKey;
    if (apiKey.isNotEmpty) {
      // Try OpenWeatherMap first
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return {
            'cloudCover': data['clouds']['all'] ?? 0,
            'temperature': data['main']['temp'] ?? 0,
            'humidity': data['main']['humidity'] ?? 0,
            'windSpeed': data['wind']['speed'] ?? 0,
            'description': data['weather'][0]['description'] ?? '',
            'icon': data['weather'][0]['icon'] ?? '',
            'provider': 'OpenWeatherMap',
          };
        } else {
          print('OpenWeatherMap error: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        print('OpenWeatherMap exception: $e');
      }
    }
    // Fallback to Open-Meteo (no API key required)
    try {
      final response = await http.get(
        Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=cloudcover,temperature_2m,humidity_2m,wind_speed_10m'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'] ?? {};
        return {
          'cloudCover': current['cloudcover'] ?? 0,
          'temperature': current['temperature_2m'] ?? 0,
          'humidity': current['humidity_2m'] ?? 0,
          'windSpeed': current['wind_speed_10m'] ?? 0,
          'description': 'Cloud cover from Open-Meteo',
          'icon': '',
          'provider': 'Open-Meteo',
        };
      } else {
        final errorMsg = 'Open-Meteo error: ${response.statusCode} ${response.body}';
        print(errorMsg);
        return {'error': errorMsg};
      }
    } catch (e) {
      final errorMsg = 'Open-Meteo exception: $e';
      print(errorMsg);
      return {'error': errorMsg};
    }
  }
} 