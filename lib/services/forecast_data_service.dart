import 'dart:convert';
import 'package:http/http.dart' as http;

class ForecastData {
  final List<String> times;
  final List<double> bzValues;

  ForecastData({required this.times, required this.bzValues});
}

class ForecastDataService {
  static Future<ForecastData> fetchBzData() async {
    final url = Uri.parse('https://services.swpc.noaa.gov/products/solar-wind/mag-2-hour.json');
    final response = await http.get(url);

    final List<dynamic> data = jsonDecode(response.body);
    final rows = data.skip(1).where((row) => double.tryParse(row[3]) != null);

    final times = <String>[];
    final bzValues = <double>[];

    for (final row in rows) {
      times.add(row[0].substring(11, 16));
      bzValues.add(double.parse(row[3]));
    }

    return ForecastData(times: times, bzValues: bzValues);
  }

  static Future<int?> fetchKpIndex() async {
    final url = Uri.parse("https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json");
    final response = await http.get(url);
    final List<dynamic> data = jsonDecode(response.body);
    return int.tryParse(data.last[1]);
  }
}
