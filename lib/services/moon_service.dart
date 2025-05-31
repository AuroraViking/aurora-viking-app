import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class MoonService {
  static const String _baseUrl = 'https://aa.usno.navy.mil/api/rstt/oneday';

  Future<Map<String, dynamic>> getMoonData(Position position) async {
    try {
      final date = DateTime.now();
      final url = 'https://aa.usno.navy.mil/api/rstt/oneday?date=${date.year}-${date.month}-${date.day}&coords=${position.latitude}, ${position.longitude}';
      
      print('MoonService: Requesting $url');
      
      final response = await http.get(Uri.parse(url));
      print('MoonService: Response status: ${response.statusCode}');
      print('MoonService: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final moonData = data['properties']['data'];
        
        // Parse moonrise and moonset times from moondata array
        String moonrise = 'N/A';
        String moonset = 'N/A';
        
        if (moonData['moondata'] != null) {
          for (var event in moonData['moondata']) {
            if (event['phen'] == 'Rise') {
              moonrise = event['time'] ?? 'N/A';
            } else if (event['phen'] == 'Set') {
              moonset = event['time'] ?? 'N/A';
            }
          }
        }

        return {
          'phase': moonData['curphase'] ?? 'N/A',
          'illumination': moonData['fracillum'] ?? 'N/A',
          'moonrise': moonrise,
          'moonset': moonset,
          'nextPhase': moonData['closestphase']['phase'] ?? 'N/A',
          'nextPhaseTime': '${moonData['closestphase']['time']} on ${moonData['closestphase']['month']}/${moonData['closestphase']['day']}/${moonData['closestphase']['year']}',
        };
      } else {
        throw Exception('Failed to load moon data: ${response.statusCode}');
      }
    } catch (e) {
      print('MoonService: Error fetching moon data: $e');
      return {
        'phase': 'N/A',
        'illumination': 'N/A',
        'moonrise': 'N/A',
        'moonset': 'N/A',
        'nextPhase': 'N/A',
        'nextPhaseTime': 'N/A',
      };
    }
  }

  String _formatTime(String? time) {
    if (time == null) return 'N/A';
    try {
      // US Naval Observatory returns time in HH:mm format
      final parts = time.split(':');
      if (parts.length != 2) return time;
      
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      
      // Convert to 12-hour format
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      
      return '$hour12:$minute $period';
    } catch (e) {
      print('Error formatting time: $e');
      return time;
    }
  }
} 