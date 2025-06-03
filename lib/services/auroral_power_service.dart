import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../widgets/forecast/auroral_power_chart.dart';

class AuroralPowerService {
  final String auroralPowerUrl = 'https://services.swpc.noaa.gov/json/ovation_aurora_latest.json';
  final List<AuroraPowerPoint> _historicalData = [];
  static const int maxDataPoints = 24; // Store last 24 data points
  
  // Add StreamController for data updates
  final _dataController = StreamController<List<AuroraPowerPoint>>.broadcast();
  Stream<List<AuroraPowerPoint>> get dataStream => _dataController.stream;

  Future<Map<String, dynamic>> getAuroralPowerStatus() async {
    try {
      print('Fetching auroral power from: $auroralPowerUrl');
      final response = await http.get(Uri.parse(auroralPowerUrl));

      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('Parsed data: $data');

          // Parse the coordinates data to calculate auroral power
          final coordinates = data['coordinates'] as List<dynamic>;
          
          // Calculate total auroral power for both hemispheres
          double northPower = 0.0;
          double southPower = 0.0;
          
          for (var coord in coordinates) {
            final latitude = (coord[1] as num).toDouble();
            final auroraValue = (coord[2] as num).toDouble();
            
            if (latitude > 0) {
              northPower += auroraValue;
            } else {
              southPower += auroraValue;
            }
          }

          // Convert to gigawatts (assuming the values are in some unit that needs conversion)
          northPower = northPower / 1000;
          southPower = southPower / 1000;

          final observationTime = DateTime.parse(data['Observation Time']);
          final forecastTime = DateTime.parse(data['Forecast Time']);

          // Add to historical data
          _historicalData.add(AuroraPowerPoint(observationTime, northPower));
          
          // Keep only the last maxDataPoints
          if (_historicalData.length > maxDataPoints) {
            _historicalData.removeAt(0);
          }

          // Notify listeners of the updated data
          _dataController.add(_historicalData);

          print('Northern Hemisphere Power: $northPower GW');
          print('Southern Hemisphere Power: $southPower GW');
          print('Observation Time: $observationTime');
          print('Forecast Time: $forecastTime');

          return {
            'isActive': northPower > 20, // Threshold for significant auroral activity
            'northPower': northPower,
            'southPower': southPower,
            'observationTime': observationTime,
            'forecastTime': forecastTime,
            'historicalData': _historicalData,
            'error': null,
          };
        } catch (e) {
          print('Error parsing response: $e');
          return _createErrorResponse('Error parsing response: $e');
        }
      } else {
        print('Failed to fetch auroral power. Status code: ${response.statusCode}');
        return _createErrorResponse('Failed to fetch auroral power. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching auroral power: $e');
      return _createErrorResponse('Error fetching auroral power: $e');
    }
  }

  Map<String, dynamic> _createErrorResponse(String error) {
    return {
      'isActive': false,
      'northPower': 0.0,
      'southPower': 0.0,
      'observationTime': DateTime.now(),
      'forecastTime': DateTime.now(),
      'historicalData': _historicalData,
      'error': error,
    };
  }

  String getAuroralPowerDescription(double power) {
    if (power > 50) {
      return 'Major auroral activity detected!';
    } else if (power > 30) {
      return 'Strong auroral activity detected';
    } else if (power > 20) {
      return 'Moderate auroral activity detected';
    } else if (power > 10) {
      return 'Minor auroral activity detected';
    } else {
      return 'No significant auroral activity';
    }
  }

  void dispose() {
    _dataController.close();
  }
} 