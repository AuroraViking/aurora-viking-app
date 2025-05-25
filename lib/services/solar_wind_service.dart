// lib/services/solar_wind_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class SolarWindData {
  final double speed;
  final double density;
  final double? bt;

  SolarWindData({required this.speed, required this.density, this.bt});
}

class BzHistory {
  final List<double> bzValues;
  final List<String> times;

  BzHistory({required this.bzValues, required this.times});
}

class SolarWindService {
  static const _plasmaUrl =
      'https://services.swpc.noaa.gov/products/solar-wind/plasma-2-hour.json';
  static const _magneticUrl =
      'https://services.swpc.noaa.gov/products/solar-wind/mag-2-hour.json';

  static Future<SolarWindData> fetchData() async {
    try {
      final plasmaRes = await http.get(Uri.parse(_plasmaUrl));
      final magRes = await http.get(Uri.parse(_magneticUrl));

      if (plasmaRes.statusCode == 200 && magRes.statusCode == 200) {
        final plasma = jsonDecode(plasmaRes.body) as List<dynamic>;
        final mag = jsonDecode(magRes.body) as List<dynamic>;

        final latestPlasma = plasma.last;
        final latestMag = mag.last;

        final speed = double.tryParse(latestPlasma[2].toString()) ?? 0;
        final density = double.tryParse(latestPlasma[1].toString()) ?? 0;
        final bt = double.tryParse(latestMag[2].toString());

        return SolarWindData(speed: speed, density: density, bt: bt);
      } else {
        throw Exception('Failed to load solar wind data');
      }
    } catch (e) {
      print('Error fetching solar wind data: \$e');
      return SolarWindData(speed: 0, density: 0, bt: null);
    }
  }

  static Future<BzHistory> fetchBzHistory() async {
    try {
      final response = await http.get(Uri.parse(_magneticUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final rows = data.skip(1).where((row) => double.tryParse(row[3].toString()) != null);
        final times = rows.map((r) => r[0].toString().substring(11, 16)).toList();
        final bzValues = rows.map((r) => double.parse(r[3].toString())).toList();

        return BzHistory(bzValues: bzValues, times: times);
      } else {
        throw Exception('Failed to load Bz history');
      }
    } catch (e) {
      print('Error fetching Bz history: \$e');
      return BzHistory(bzValues: [], times: []);
    }
  }
}