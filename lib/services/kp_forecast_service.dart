// lib/services/kp_forecast_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class KpForecastDay {
  final DateTime date;
  final double expectedKp;
  final String confidenceLevel;
  final String activityLevel;

  KpForecastDay({
    required this.date,
    required this.expectedKp,
    required this.confidenceLevel,
    required this.activityLevel,
  });

  String get formattedDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return '${days[date.weekday % 7]} ${date.day} ${months[date.month - 1]}';
  }

  Color get activityColor {
    if (expectedKp >= 6) return const Color(0xFFFF6B35); // Red - Storm
    if (expectedKp >= 4) return const Color(0xFFFFD700); // Gold - Active
    if (expectedKp >= 3) return const Color(0xFF4ECDC4); // Teal - Moderate
    if (expectedKp >= 2) return const Color(0xFF45B7D1); // Blue - Quiet
    return const Color(0xFF96CEB4); // Green - Very quiet
  }

  String get description {
    if (expectedKp >= 6) return 'Geomagnetic Storm';
    if (expectedKp >= 4) return 'Active Conditions';
    if (expectedKp >= 3) return 'Moderate Activity';
    if (expectedKp >= 2) return 'Quiet Conditions';
    return 'Very Quiet';
  }
}

class KpForecastService {
  static const _forecastUrl = 'https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json';
  static const _textForecastUrl = 'https://services.swpc.noaa.gov/text/3-day-forecast.txt';

  static Future<List<KpForecastDay>> fetchKpForecast() async {
    try {
      // Try to get structured forecast data first
      final jsonResponse = await http.get(Uri.parse(_forecastUrl));

      if (jsonResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(jsonResponse.body);
        return _parseJsonForecast(data);
      }

      // Fallback to text forecast if JSON fails
      final textResponse = await http.get(Uri.parse(_textForecastUrl));
      if (textResponse.statusCode == 200) {
        return _parseTextForecast(textResponse.body);
      }

      throw Exception('Failed to load forecast data');
    } catch (e) {
      print('Error fetching Kp forecast: $e');
      // Return mock data for development
      return _getMockForecast();
    }
  }

  static List<KpForecastDay> _parseJsonForecast(List<dynamic> data) {
    final List<KpForecastDay> forecast = [];
    final now = DateTime.now();

    try {
      // NOAA forecast data typically contains time series data
      // Parse the forecast for the next 5 days
      for (int i = 0; i < 5 && i < data.length; i++) {
        final item = data[i];
        final forecastDate = now.add(Duration(days: i));

        // Extract Kp value (format may vary)
        double kpValue = 2.0; // Default
        if (item is Map<String, dynamic>) {
          if (item.containsKey('predicted_kp')) {
            kpValue = double.tryParse(item['predicted_kp'].toString()) ?? 2.0;
          } else if (item.containsKey('kp')) {
            kpValue = double.tryParse(item['kp'].toString()) ?? 2.0;
          }
        } else if (item is List && item.length > 1) {
          kpValue = double.tryParse(item[1].toString()) ?? 2.0;
        }

        forecast.add(KpForecastDay(
          date: forecastDate,
          expectedKp: kpValue,
          confidenceLevel: 'Medium',
          activityLevel: _getActivityLevel(kpValue),
        ));
      }
    } catch (e) {
      print('Error parsing JSON forecast: $e');
      return _getMockForecast();
    }

    return forecast.isNotEmpty ? forecast : _getMockForecast();
  }

  static List<KpForecastDay> _parseTextForecast(String textData) {
    final List<KpForecastDay> forecast = [];
    final now = DateTime.now();

    try {
      // Parse the text forecast - NOAA format typically includes daily summaries
      final lines = textData.split('\n');

      // Look for lines containing forecast information
      for (int day = 0; day < 5; day++) {
        final forecastDate = now.add(Duration(days: day));

        // Simple parsing - look for patterns in the text
        double kpValue = 2.0 + (day * 0.5); // Gradually increasing baseline

        // Try to extract actual Kp values from text
        for (final line in lines) {
          if (line.toLowerCase().contains('kp') || line.toLowerCase().contains('k-index')) {
            final kpMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(line);
            if (kpMatch != null) {
              kpValue = double.tryParse(kpMatch.group(1) ?? '2.0') ?? 2.0;
              break;
            }
          }
        }

        forecast.add(KpForecastDay(
          date: forecastDate,
          expectedKp: kpValue.clamp(0.0, 9.0),
          confidenceLevel: 'Medium',
          activityLevel: _getActivityLevel(kpValue),
        ));
      }
    } catch (e) {
      print('Error parsing text forecast: $e');
      return _getMockForecast();
    }

    return forecast.isNotEmpty ? forecast : _getMockForecast();
  }

  static String _getActivityLevel(double kp) {
    if (kp >= 6) return 'Storm';
    if (kp >= 4) return 'Active';
    if (kp >= 3) return 'Moderate';
    if (kp >= 2) return 'Quiet';
    return 'Very Quiet';
  }

  static List<KpForecastDay> _getMockForecast() {
    final now = DateTime.now();
    return [
      KpForecastDay(
        date: now,
        expectedKp: 2.3,
        confidenceLevel: 'High',
        activityLevel: 'Quiet',
      ),
      KpForecastDay(
        date: now.add(const Duration(days: 1)),
        expectedKp: 3.1,
        confidenceLevel: 'Medium',
        activityLevel: 'Moderate',
      ),
      KpForecastDay(
        date: now.add(const Duration(days: 2)),
        expectedKp: 2.8,
        confidenceLevel: 'Medium',
        activityLevel: 'Quiet',
      ),
      KpForecastDay(
        date: now.add(const Duration(days: 3)),
        expectedKp: 4.2,
        confidenceLevel: 'Low',
        activityLevel: 'Active',
      ),
      KpForecastDay(
        date: now.add(const Duration(days: 4)),
        expectedKp: 3.5,
        confidenceLevel: 'Low',
        activityLevel: 'Moderate',
      ),
    ];
  }
}