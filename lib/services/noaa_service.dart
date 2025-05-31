import 'dart:convert';
import 'package:http/http.dart' as http;

class NoaaService {
  static const String _baseUrl = 'https://services.swpc.noaa.gov/json';

  static Future<Map<String, dynamic>> getAlerts() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/alerts.json'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load alerts: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load alerts: $e');
    }
  }

  static Future<Map<String, dynamic>> getNotifications() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/notifications.json'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load notifications: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to load notifications: $e');
    }
  }
} 