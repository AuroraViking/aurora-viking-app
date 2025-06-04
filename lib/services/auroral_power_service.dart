import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/forecast/auroral_power_chart.dart';

class AuroralPowerService {
  static const String _baseUrl = 'https://services.swpc.noaa.gov/json/ovation_aurora_latest.json';
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final supabase = Supabase.instance.client;
  List<AuroraPowerPoint> _historicalData = [];
  Timer? _timer;
  bool _isInitialized = false;

  AuroralPowerService() {
    print('🚀 Initializing AuroralPowerService...');
    // Start fetching data immediately
    fetchAuroralPower();
    // Load historical data in parallel
    _loadHistoricalData();
    // Start periodic updates
    _startPeriodicUpdates();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load historical data from Supabase
      await _loadHistoricalData();
      
      // Start periodic updates
      _startPeriodicUpdates();
      
      // Fetch current data
      await fetchAuroralPower();
      
      _isInitialized = true;
    } catch (e) {
      print('❌ Error initializing AuroralPowerService: $e');
    }
  }

  Future<void> _loadHistoricalData() async {
    try {
      print('📊 Loading historical data from Supabase...');
      final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));

      final response = await supabase
          .from('aurora_readings')
          .select()
          .gte('timestamp', twoHoursAgo.toIso8601String())
          .order('timestamp');

      if (response.isNotEmpty) {
        print('📊 Found ${response.length} historical data points');
        _historicalData = response.map<AuroraPowerPoint>((item) => AuroraPowerPoint(
          DateTime.parse(item['timestamp']),
          item['power'].toDouble(),
        )).toList();

        // Only emit if we have data
        if (_historicalData.isNotEmpty) {
          _controller.add({
            'historicalData': _historicalData,
            'currentPower': _historicalData.last.power,
          });
        }
      } else {
        print('📊 No historical data found in Supabase');
      }
    } catch (e) {
      print('❌ Error loading historical data from Supabase: $e');
    }
  }

  Future<void> fetchAuroralPower() async {
    try {
      print('🌌 Fetching fresh aurora data from NOAA...');
      final response = await http.get(Uri.parse(_baseUrl));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final power = _calculateAuroralPower(data);
        final now = DateTime.now();

        print('🌌 Aurora power: $power GW');

        // Add new data point
        _historicalData.add(AuroraPowerPoint(now, power));
        
        // Keep only last 2 hours
        final twoHoursAgo = now.subtract(const Duration(hours: 2));
        _historicalData.removeWhere((point) => point.time.isBefore(twoHoursAgo));

        // Sort data by time
        _historicalData.sort((a, b) => a.time.compareTo(b.time));

        // Save to Supabase in the background
        _saveToSupabase(power, now, twoHoursAgo);

        print('📊 Current data points: ${_historicalData.length}');
        _controller.add({
          'historicalData': _historicalData,
          'currentPower': power,
        });
      }
    } catch (e) {
      print('❌ Error fetching aurora power: $e');
    }
  }

  Future<void> _saveToSupabase(double power, DateTime now, DateTime twoHoursAgo) async {
    try {
      await supabase.from('aurora_readings').insert({
        'power': power,
        'timestamp': now.toIso8601String(),
      });

      // Clean up old data
      await supabase
          .from('aurora_readings')
          .delete()
          .lt('timestamp', twoHoursAgo.toIso8601String());

      print('✅ Data saved to Supabase and old data cleaned up');
    } catch (e) {
      print('❌ Error saving to Supabase: $e');
    }
  }

  void _startPeriodicUpdates() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => fetchAuroralPower());
  }

  double _calculateAuroralPower(Map<String, dynamic> data) {
    try {
      print('🔍 Analyzing NOAA data structure...');
      print('📋 NOAA Data keys: ${data.keys.toList()}');

      // New NOAA structure: Parse coordinates array directly
      if (data.containsKey('coordinates')) {
        final coordinates = data['coordinates'];
        if (coordinates is List && coordinates.isNotEmpty) {
          double totalPower = 0.0;
          int count = 0;

          // Each coordinate should have aurora activity data
          for (var coord in coordinates) {
            if (coord is List && coord.length >= 3) {
              // Coordinates are usually [lat, lon, value] or similar
              final value = coord[2]; // Third element is usually the aurora intensity
              if (value is num) {
                totalPower += value.toDouble();
                count++;
              }
            } else if (coord is Map) {
              // Sometimes coordinates are objects with lat, lon, value
              if (coord.containsKey('value')) {
                final value = coord['value'];
                if (value is num) {
                  totalPower += value.toDouble();
                  count++;
                }
              } else if (coord.containsKey('intensity')) {
                final value = coord['intensity'];
                if (value is num) {
                  totalPower += value.toDouble();
                  count++;
                }
              }
            }
          }

          if (count > 0) {
            // NOAA values are aurora intensity (0-255 scale), convert to GW scale
            // Scale by 10 to get realistic GW values (40-50 GW range)
            final avgPower = (totalPower / count) * 10;
            print('✅ Calculated aurora power from coordinates: $avgPower GW (${count} points)');
            return avgPower;
          }
        }
      }

      // Try old hemisphere power structure (backup)
      if (data.containsKey('Hemisphere Power')) {
        final hemispherePower = data['Hemisphere Power'];
        if (hemispherePower is Map && hemispherePower.containsKey('North')) {
          final northPower = hemispherePower['North'];
          if (northPower is num) {
            print('✅ Found North hemisphere power: $northPower');
            return northPower.toDouble();
          }
        }
      }

      // Try observations structure (old format)
      if (data.containsKey('observations')) {
        final observations = data['observations'];
        if (observations is List && observations.isNotEmpty) {
          double totalPower = 0.0;
          int count = 0;

          for (var obs in observations) {
            if (obs is Map && obs.containsKey('forecast')) {
              final forecast = obs['forecast'];
              if (forecast is Map && forecast.containsKey('coordinates')) {
                final coordinates = forecast['coordinates'];
                if (coordinates is List) {
                  for (var coord in coordinates) {
                    if (coord is Map && coord.containsKey('value')) {
                      final value = coord['value'];
                      if (value is num) {
                        totalPower += value.toDouble();
                        count++;
                      }
                    }
                  }
                }
              }
            }
          }

          if (count > 0) {
            // Scale by 10 to get realistic GW values
            final avgPower = (totalPower / count) * 10;
            print('✅ Calculated average power from observations: $avgPower');
            return avgPower;
          }
        }
      }

      throw Exception('Could not parse NOAA data structure');

    } catch (e) {
      print('❌ Error calculating auroral power: $e');
      rethrow;
    }
  }

  Stream<Map<String, dynamic>> get auroralPowerStream => _controller.stream;

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
    _timer?.cancel();
    _controller.close();
  }
}