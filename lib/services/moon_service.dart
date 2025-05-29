import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class MoonService {
  static const String _baseUrl = 'https://aa.usno.navy.mil/api/rstt/oneday';

  Future<Map<String, dynamic>> getMoonData(Position position) async {
    final now = DateTime.now();
    final date = '${now.year}-${now.month}-${now.day}';
    final coords = '${position.latitude}, ${position.longitude}';
    
    final url = '$_baseUrl?date=$date&coords=$coords';
    print('MoonService: Requesting $url');
    
    final response = await http.get(Uri.parse(url));
    print('MoonService: Response status: ${response.statusCode}');
    print('MoonService: Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      if (data['error'] != null) {
        throw Exception('API returned error: ${data['error']}');
      }

      final moonData = data['properties']['data']['moondata'];
      final curPhase = data['properties']['data']['curphase'];
      final fracIllum = data['properties']['data']['fracillum'];
      final closestPhase = data['properties']['data']['closestphase'];

      // Check for continuous visibility conditions first
      bool isMoonAlwaysVisible = false;
      bool isMoonAlwaysHidden = false;
      String? moonrise;
      String? moonset;

      for (var phenomenon in moonData) {
        if (phenomenon['phen'] == 'Object continuously above the Horizon') {
          isMoonAlwaysVisible = true;
        } else if (phenomenon['phen'] == 'Object continuously below the Horizon') {
          isMoonAlwaysHidden = true;
        } else if (phenomenon['phen'] == 'Moonrise') {
          moonrise = _formatTime(phenomenon['time']);
        } else if (phenomenon['phen'] == 'Moonset') {
          moonset = _formatTime(phenomenon['time']);
        }
      }

      // Parse the illumination percentage
      String illumination;
      try {
        // Remove the % symbol and parse as double
        final illumValue = double.parse(fracIllum.replaceAll('%', ''));
        illumination = illumValue.toStringAsFixed(1);
      } catch (e) {
        print('Error parsing illumination: $e');
        illumination = 'N/A';
      }

      return {
        'moonrise': isMoonAlwaysVisible ? 'Always above horizon' : 
                   isMoonAlwaysHidden ? 'Always below horizon' : 
                   moonrise ?? 'N/A',
        'moonset': isMoonAlwaysVisible ? 'Always above horizon' : 
                  isMoonAlwaysHidden ? 'Always below horizon' : 
                  moonset ?? 'N/A',
        'phase': curPhase,
        'illumination': illumination,
        'nextPhase': closestPhase['phase'],
        'nextPhaseTime': _formatTime(closestPhase['time']),
      };
    } else {
      throw Exception('Failed to load moon data: ${response.statusCode}');
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