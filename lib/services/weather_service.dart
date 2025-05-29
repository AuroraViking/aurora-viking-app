import 'package:http/http.dart' as http;
import 'dart:convert';

class WeatherService {
  static const String _apiKey = 'b7889cba97489be6e2f825f3861feb23';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  Future<Map<String, dynamic>> getWeatherData(double latitude, double longitude) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'temperature': data['main']['temp'],
        'humidity': data['main']['humidity'],
        'windSpeed': data['wind']['speed'],
        'cloudCover': data['clouds']['all'],
        'weatherDescription': data['weather'][0]['description'],
        'weatherIcon': data['weather'][0]['icon'],
      };
    } else {
      print('Weather API error: ${response.statusCode} ${response.body}');
      throw Exception('Failed to load weather data');
    }
  }
} 