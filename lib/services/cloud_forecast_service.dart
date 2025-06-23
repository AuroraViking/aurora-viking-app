import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudForecastService {
  final String baseUrl = 'https://api.open-meteo.com/v1/forecast';
  final _client = http.Client();
  static const _requestsPerSecond = 10;
  static const _requestInterval = Duration(milliseconds: 1000 ~/ _requestsPerSecond); // 100ms between requests
  DateTime? _lastRequestTime;

  Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _requestInterval) {
        await Future.delayed(_requestInterval - timeSinceLastRequest);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  Future<Map<String, dynamic>> _makeRequest(String url, {int retryCount = 0}) async {
    await _waitForRateLimit();
    
    try {
      final response = await _client.get(Uri.parse(url));
      
      if (response.statusCode == 429) {
        if (retryCount < 3) {
          // Exponential backoff: 1s, 2s, 4s
          final backoff = Duration(seconds: 1 << retryCount);
          await Future.delayed(backoff);
          return _makeRequest(url, retryCount: retryCount + 1);
        }
        throw Exception('Rate limit exceeded after 3 retries');
      }
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load cloud forecast: ${response.statusCode}');
      }
      
      return json.decode(response.body);
    } catch (e) {
      if (retryCount < 3 && e.toString().contains('429')) {
        final backoff = Duration(seconds: 1 << retryCount);
        await Future.delayed(backoff);
        return _makeRequest(url, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCloudForecast(double latitude, double longitude) async {
    final url = '$baseUrl?latitude=$latitude&longitude=$longitude&hourly=cloudcover&timezone=auto';
    return _makeRequest(url);
  }

  Future<List<Map<String, dynamic>>> getCloudForecastForArea(
    double centerLat,
    double centerLng,
    int gridSize,
    double spacing,
  ) async {
    final points = <Map<String, dynamic>>[];
    
    // Create grid points
    for (int x = -gridSize ~/ 2; x <= gridSize ~/ 2; x++) {
      for (int y = -gridSize ~/ 2; y <= gridSize ~/ 2; y++) {
        if (x == 0 && y == 0) continue; // Skip center point
        
        final lat = centerLat + (x * spacing);
        final lng = centerLng + (y * spacing);
        
        points.add({
          'lat': lat,
          'lng': lng,
          'x': x,
          'y': y,
        });
      }
    }
    
    // Process all points with exact rate limiting
    final results = <Map<String, dynamic>>[];
    for (final point in points) {
      final forecast = await getCloudForecast(point['lat'], point['lng']);
      results.add(forecast);
    }
    
    return results;
  }

  Future<List<Map<String, dynamic>>> getCloudForecastForPoints(List<Map<String, double>> points) async {
    final results = <Map<String, dynamic>>[];
    
    for (final point in points) {
      final forecast = await getCloudForecast(point['lat']!, point['lng']!);
      // Add the row and column information to the forecast data
      forecast['row'] = point['row'];
      forecast['col'] = point['col'];
      results.add(forecast);
    }
    
    return results;
  }

  void dispose() {
    _client.close();
  }
}