import 'package:flutter/material.dart';
import '../services/solar_wind_service.dart';
import '../services/kp_service.dart';
import '../services/kp_forecast_service.dart';
import '../services/aurora_message_service.dart';
import '../services/cloud_cover_service.dart';
import '../widgets/forecast/forecast_chart_widget.dart';
import '../widgets/forecast/cloud_cover_map.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../services/light_pollution_service.dart';
import '../services/sunrise_sunset_service.dart';
import '../widgets/forecast/bortle_map.dart';
import '../services/moon_service.dart';

class ForecastTab extends StatefulWidget {
  const ForecastTab({super.key});

  @override
  State<ForecastTab> createState() => _ForecastTabState();
}

class _ForecastTabState extends State<ForecastTab> {
  List<double> bzValues = [];
  List<String> times = [];
  double kp = 0.0;
  double speed = 0.0;
  double density = 0.0;
  List<KpForecastDay> kpForecast = [];
  bool isLoading = true;
  
  // Cloud cover data
  Position? _currentPosition;
  Map<String, dynamic>? _cloudCoverData;
  bool _isLoadingCloudData = true;

  final WeatherService _weatherService = WeatherService();
  final LightPollutionService _lightPollutionService = LightPollutionService();
  final SunriseSunsetService _sunService = SunriseSunsetService();
  final MoonService _moonService = MoonService();
  Map<String, dynamic>? _weatherData;
  Map<String, dynamic>? _lightPollutionData;
  Map<String, dynamic>? _sunData;
  Map<String, dynamic>? _moonData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCloudCoverData();
  }

  Future<void> _loadCloudCoverData() async {
    try {
      setState(() => _isLoadingCloudData = true);
      
      // Get current location
      final position = await CloudCoverService.getCurrentLocation();
      
      // Get cloud cover data
      final cloudData = await CloudCoverService.getCloudCoverData(position);
      
      setState(() {
        _currentPosition = position;
        _cloudCoverData = cloudData;
        _isLoadingCloudData = false;
      });
    } catch (e) {
      print('Error loading cloud cover data: $e');
      setState(() => _isLoadingCloudData = false);
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        _error = null;
      });

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get weather data
      _weatherData = await _weatherService.getWeatherData(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      // Get light pollution data
      _lightPollutionData = await _lightPollutionService.getLightPollutionData(
        _currentPosition!,
      );

      // Get sun data
      _sunData = await _sunService.getSunData(_currentPosition!);

      // Get moon data
      _moonData = await _moonService.getMoonData(_currentPosition!);

      final swData = await SolarWindService.fetchData();
      final bzRes = await SolarWindService.fetchBzHistory();
      final kpIndex = await KpService.fetchCurrentKp();
      final forecast = await KpForecastService.fetchKpForecast();

      setState(() {
        bzValues = bzRes.bzValues;
        times = bzRes.times;
        kp = kpIndex;
        speed = swData.speed;
        density = swData.density;
        kpForecast = forecast;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        isLoading = false;
      });
    }
  }

  double _calculateBzH(List<double> values) {
    if (values.isEmpty) return 0.0;
    final recent = values.length > 60 ? values.takeLast(60) : values;
    final sum = recent.where((bz) => bz < 0).fold(0.0, (acc, bz) => acc + (-bz / 60));
    return double.parse(sum.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.tealAccent,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_error',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentPosition == null || _weatherData == null || _lightPollutionData == null || _sunData == null) {
      return const Center(
        child: Text('No data available'),
      );
    }

    final bzH = _calculateBzH(bzValues);
    final combinedMessage = AuroraMessageService.getCombinedAuroraMessage(kp, bzH);
    final statusColor = AuroraMessageService.getStatusColor(kp, bzH);
    final auroraAdvice = AuroraMessageService.getAuroraAdvice(kp, bzH);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Header
            const Text(
              'Aurora Forecast',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.tealAccent,
                shadows: [Shadow(color: Colors.tealAccent, blurRadius: 8)],
              ),
            ),

            const SizedBox(height: 16),

            // Aurora Status Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor.withOpacity(0.2),
                    statusColor.withOpacity(0.1),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                combinedMessage,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: statusColor.withOpacity(0.5), blurRadius: 10),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            // Aurora Advice Box
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                auroraAdvice,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // Info Box
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.tealAccent.withOpacity(0.1),
                    Colors.cyanAccent.withOpacity(0.05),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.tealAccent.withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDataRow('BzH', '$bzH nT', Colors.tealAccent, isHighlighted: true),
                        const SizedBox(height: 8),
                        _buildDataRow('Kp Index', kp.toStringAsFixed(1), Colors.white),
                        const SizedBox(height: 8),
                        _buildDataRow('Speed', '${speed.toInt()} km/s', Colors.white70),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDataRow('Density', '${density.toStringAsFixed(1)} /cm³', Colors.white70),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.update, color: Colors.grey, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Live Data',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Chart with fixed height
            SizedBox(
              height: 500, // Increased height for chart
              child: ForecastChartWidget(
                bzValues: bzValues,
                times: times,
                kp: kp,
                speed: speed,
                density: density,
              ),
            ),

            const SizedBox(height: 20),

            // 5-Day Kp Forecast Section
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.tealAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '5-Day Kp Forecast',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.tealAccent,
                          shadows: [Shadow(color: Colors.tealAccent, blurRadius: 8)],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildKpForecastList(),
                ],
              ),
            ),

            const SizedBox(height: 20), // Bottom padding for scroll

            // Moon Info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.tealAccent.withOpacity(0.1),
                    Colors.cyanAccent.withOpacity(0.05),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.tealAccent.withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.nightlight_round, color: Colors.tealAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Moon Info',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.tealAccent,
                                shadows: [Shadow(color: Colors.tealAccent, blurRadius: 8)],
                              ),
                            ),
                            Text(
                              _formatLocation(_currentPosition),
                              style: TextStyle(
                                color: Colors.tealAccent.withOpacity(0.7),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showMoonInfoHelp(context),
                        child: Icon(
                          Icons.help_outline,
                          color: Colors.tealAccent,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDataRow('Phase', _moonData?['phase'] ?? 'N/A', Colors.white),
                            const SizedBox(height: 8),
                            _buildDataRow('Illumination', '${_moonData?['illumination'] ?? 'N/A'}%', Colors.white70),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDataRow('Moonrise', _moonData?['moonrise'] ?? 'N/A', Colors.white70),
                            const SizedBox(height: 8),
                            _buildDataRow('Moonset', _moonData?['moonset'] ?? 'N/A', Colors.white70),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.tealAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.tealAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Next Phase: ${_moonData?['nextPhase'] ?? 'N/A'} at ${_moonData?['nextPhaseTime'] ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Sun and Twilight Info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.tealAccent.withOpacity(0.1),
                    Colors.cyanAccent.withOpacity(0.05),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.tealAccent.withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wb_twilight, color: Colors.tealAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sun and Twilight Info',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.tealAccent,
                                shadows: [Shadow(color: Colors.tealAccent, blurRadius: 8)],
                              ),
                            ),
                            Text(
                              _formatLocation(_currentPosition),
                              style: TextStyle(
                                color: Colors.tealAccent.withOpacity(0.7),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDataRow('Sunrise', _sunData?['sunrise'] ?? 'N/A', Colors.white),
                            const SizedBox(height: 8),
                            _buildDataRow('Sunset', _sunData?['sunset'] ?? 'N/A', Colors.white),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDataRow('Day Length', _sunData?['dayLength'] ?? 'N/A', Colors.white70),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.tealAccent.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Astronomical Twilight',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDataRow('Start', _sunData?['astronomicalTwilightStart'] ?? 'N/A', Colors.white70),
                        const SizedBox(height: 4),
                        _buildDataRow('End', _sunData?['astronomicalTwilightEnd'] ?? 'N/A', Colors.white70),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTwilightConditionInfo(_sunData),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpForecastList() {
    if (kpForecast.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            'Forecast data unavailable',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Column(
      children: kpForecast.map((forecast) => _buildKpForecastCard(forecast)).toList(),
    );
  }

  Widget _buildKpForecastCard(KpForecastDay forecast) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            forecast.activityColor.withOpacity(0.15),
            Colors.black.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: forecast.activityColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forecast.formattedDate,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  forecast.date.day == DateTime.now().day ? 'Today' : '',
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Kp Value
          Container(
            width: 60,
            height: 40,
            decoration: BoxDecoration(
              color: forecast.activityColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: forecast.activityColor.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                'Kp ${forecast.expectedKp.toStringAsFixed(1)}',
                style: TextStyle(
                  color: forecast.activityColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Activity Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  forecast.description,
                  style: TextStyle(
                    color: forecast.activityColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Confidence: ${forecast.confidenceLevel}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Activity Indicator
          Container(
            width: 8,
            height: 30,
            decoration: BoxDecoration(
              color: forecast.activityColor,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: forecast.activityColor.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, Color color, {bool isHighlighted = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 75,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '$label:',
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: isHighlighted ? 12 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (label == 'BzH' || label == 'Kp Index')
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: GestureDetector(
                    onTap: () => _showInfoDialog(context, label),
                    child: Icon(
                      Icons.help_outline,
                      color: color,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isHighlighted ? 8 : 6,
              vertical: isHighlighted ? 4 : 2,
            ),
            decoration: isHighlighted
                ? BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.tealAccent.withOpacity(0.3),
                      width: 0.5,
                    ),
                  )
                : null,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: isHighlighted ? 14 : 12,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                shadows: isHighlighted
                    ? [
                        Shadow(
                          color: Colors.tealAccent.withOpacity(0.5),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTwilightConditionInfo(Map<String, dynamic>? sunData) {
    final twilightStart = sunData?['astronomicalTwilightStart'];
    final twilightEnd = sunData?['astronomicalTwilightEnd'];
    
    // Format the time first to check if it's valid
    String formattedTime = _formatTwilightTime(twilightStart);
    
    // Check if we have a valid time (not N/A)
    bool hasValidTwilight = formattedTime != 'N/A';
    
    String message;
    Color messageColor;

    if (!hasValidTwilight) {
      message = 'Not dark enough tonight to spot aurora. Northern places see the midnight sun in summer.';
      messageColor = Colors.redAccent;
    } else {
      message = 'It will be dark enough for aurora spotting starting at $formattedTime.';
      messageColor = Colors.greenAccent;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: messageColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: messageColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasValidTwilight ? Icons.visibility : Icons.visibility_off,
            color: messageColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: messageColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTwilightTime(String? isoString) {
    // Check for all invalid cases first
    if (isoString == null || 
        isoString == '00:00' || 
        isoString == '1970-01-01T00:00:01+00:00' ||
        isoString == 'N/A' ||
        isoString.isEmpty) {
      return 'N/A';
    }
    try {
      // Parse ISO string and convert to local time
      final dt = DateTime.parse(isoString).toLocal();
      // Additional validation for midnight
      if (dt.hour == 0 && dt.minute == 0) {
        return 'N/A';
      }
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatLocation(Position? position) {
    if (position == null) return 'N/A';
    return '${position.latitude.toStringAsFixed(2)}°N, ${position.longitude.toStringAsFixed(2)}°E';
  }

  void _showMoonInfoHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
          ),
          title: Row(
            children: [
              Icon(Icons.nightlight_round, color: Colors.tealAccent),
              const SizedBox(width: 8),
              Text(
                'Moon Phase Guide',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMoonInfoSection(
                  'New Moon (0-5%)',
                  'Perfect for viewing faint aurora and stars. Best conditions for seeing the Milky Way and capturing deep space objects.',
                  Icons.star,
                ),
                const SizedBox(height: 12),
                _buildMoonInfoSection(
                  'Waxing/Waning Crescent (5-25%)',
                  'Good conditions for aurora viewing. Some stars visible, but the Milky Way may be slightly affected.',
                  Icons.star_half,
                ),
                const SizedBox(height: 12),
                _buildMoonInfoSection(
                  'First/Last Quarter (25-75%)',
                  'Moderate conditions. Moonlight may affect visibility of faint aurora and stars. Good for landscape photography with aurora.',
                  Icons.landscape,
                ),
                const SizedBox(height: 12),
                _buildMoonInfoSection(
                  'Full Moon (75-100%)',
                  'Bright moonlight illuminates landscapes, great for foreground in aurora photos. Not ideal for viewing faint aurora or stars.',
                  Icons.brightness_5,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.tealAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMoonInfoSection(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.tealAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.tealAccent.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.tealAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String type) {
    String title;
    String content;
    IconData icon;

    switch (type) {
      case 'BzH':
        title = 'BzH (Bz per Hour)';
        content = '''BzH is a unique metric developed by Kolbeinn Helgi Kristjansson, founder of Aurora Viking, that calculates the average negative Bz values per hour.

The equation:
BzH = Σ(-Bz/60) for Bz < 0 over the last 60 minutes

This helps predict aurora activity by considering both the magnitude and duration of negative Bz values, which indicate favorable conditions for aurora formation.

Higher BzH values suggest stronger and more sustained aurora activity.''';
        icon = Icons.calculate;
        break;

      case 'Kp Index':
        title = 'Kp Index';
        content = '''The Kp index indicates the latitude where aurora might form, but remember: aurora only forms when Bz is negative, regardless of Kp value.

Aurora Formation Latitudes:
• Kp 0-2: Iceland and northern regions
• Kp 3-4: Northern Scotland, Norway
• Kp 5: England, Denmark, Germany
• Kp 6: France, Poland
• Kp 7-9: Southern Europe, USA

Important Note:
- High Kp alone doesn't guarantee aurora
- Negative Bz is required for aurora formation
- Check both Kp and Bz for accurate predictions''';
        icon = Icons.speed;
        break;

      case 'Bz Chart':
        title = 'Bz Component';
        content = '''The Bz component measures the north-south direction of the interplanetary magnetic field (IMF).

• Negative Bz: Favorable for aurora
  - Allows solar wind to connect with Earth's magnetic field
  - Triggers geomagnetic storms
  - Higher chance of aurora activity

• Positive Bz: Unfavorable for aurora
  - Solar wind is deflected
  - Less geomagnetic activity
  - Lower chance of aurora

The chart shows Bz values over time, helping predict aurora activity.''';
        icon = Icons.show_chart;
        break;

      default:
        return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
          ),
          title: Row(
            children: [
              Icon(icon, color: Colors.tealAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              content,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.tealAccent),
              ),
            ),
          ],
        );
      },
    );
  }
}

extension TakeLast<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return skip(length - count).toList();
  }
}