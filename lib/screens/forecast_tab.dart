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
import '../widgets/forecast/cloud_forecast_map.dart';

class ForecastTab extends StatefulWidget {
  const ForecastTab({super.key});

  @override
  State<ForecastTab> createState() => _ForecastTabState();
}

class _ForecastTabState extends State<ForecastTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _loadCloudCoverData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    // Get twilight times
    final astroStart = _sunData?['astronomicalTwilightStart'] ?? 'N/A';
    final astroEnd = _sunData?['astronomicalTwilightEnd'] ?? 'N/A';
    
    // Check if it will be dark enough
    bool isNoDarkness = false;
    if (astroStart != 'N/A' && astroEnd != 'N/A') {
      isNoDarkness = (astroStart == '00:00' && astroEnd == '00:00') || 
                     (astroStart == '0:00' && astroEnd == '0:00') ||
                     (astroStart == '0:00' && astroEnd == '00:00') ||
                     (astroStart == '00:00' && astroEnd == '0:00');
    }

    // Create the combined message based on darkness conditions
    String finalMessage;
    Color messageColor;
    if (isNoDarkness) {
      finalMessage = 'It will not be dark enough at your location tonight for aurora spotting';
      messageColor = Colors.red;
    } else {
      finalMessage = 'Dark enough at $astroStart tonight - $combinedMessage';
      messageColor = statusColor;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        toolbarHeight: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Nowcast'),
              Tab(text: 'Aurora Forecast'),
              Tab(text: 'Cloud Cover'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Nowcast Tab
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Combined Aurora Status and Advice Box
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        messageColor.withOpacity(0.2),
                        messageColor.withOpacity(0.1),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: messageColor.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: messageColor.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        finalMessage,
                        style: TextStyle(
                          color: messageColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: messageColor.withOpacity(0.5), blurRadius: 10),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!isNoDarkness) ...[
                        const SizedBox(height: 12),
                        Text(
                          auroraAdvice,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Data Box
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.speed, color: Colors.tealAccent),
                              const SizedBox(width: 8),
                              Text(
                                'Current Conditions',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDataRow('BzH', bzH.toStringAsFixed(2), Colors.white, isHighlighted: true),
                                const SizedBox(height: 8),
                                _buildDataRow('Kp Index', kp.toStringAsFixed(1), Colors.white70),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDataRow('Speed', '${speed.toStringAsFixed(0)} km/s', Colors.white70),
                                const SizedBox(height: 8),
                                _buildDataRow('Density', '${density.toStringAsFixed(1)} p/cm³', Colors.white70),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Chart with fixed height
                SizedBox(
                  height: 500,
                  child: ForecastChartWidget(
                    bzValues: bzValues,
                    times: times,
                    kp: kp,
                    speed: speed,
                    density: density,
                  ),
                ),
                const SizedBox(height: 20),
                // Satellite Map
                if (_cloudCoverData != null)
                  CloudCoverMap(
                    position: _currentPosition!,
                    cloudCover: (_cloudCoverData!['cloudCover'] ?? 0).toDouble(),
                    weatherDescription: _weatherData?['description'] ?? 'N/A',
                    weatherIcon: _weatherData?['icon'] ?? 'N/A',
                    isNowcast: true,
                  ),
                const SizedBox(height: 20),
                // Sun/Daylight Info
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange.withOpacity(0.1),
                        Colors.amber.withOpacity(0.05),
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.2),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.wb_sunny, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                'Sun & Daylight',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.help_outline, color: Colors.orange),
                            onPressed: () => _showSunInfoHelp(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSunInfo(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.nightlight_round, color: Colors.tealAccent),
                              const SizedBox(width: 8),
                              Text(
                                'Moon Phase',
                                style: TextStyle(
                                  color: Colors.tealAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.help_outline, color: Colors.tealAccent),
                            onPressed: () => _showMoonInfoHelp(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildMoonInfo(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Aurora Forecast Tab
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
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
              ],
            ),
          ),
          // Cloud Cover Tab
          _currentPosition != null
              ? CloudForecastMap(
                  position: _currentPosition!,
                )
              : const Center(
                  child: Text(
                    'Waiting for location...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
        ],
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

  Widget _buildMoonInfo() {
    if (_moonData == null) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

  Widget _buildSunInfo() {
    // Check if astronomical twilight times indicate no darkness
    final astroStart = _sunData?['astronomicalTwilightStart'] ?? 'N/A';
    final astroEnd = _sunData?['astronomicalTwilightEnd'] ?? 'N/A';
    
    // More robust check for no darkness condition
    bool isNoDarkness = false;
    if (astroStart != 'N/A' && astroEnd != 'N/A') {
      isNoDarkness = (astroStart == '00:00' && astroEnd == '00:00') || 
                     (astroStart == '0:00' && astroEnd == '0:00') ||
                     (astroStart == '0:00' && astroEnd == '00:00') ||
                     (astroStart == '00:00' && astroEnd == '0:00');
    }

    print('Astro Start: $astroStart, Astro End: $astroEnd, isNoDarkness: $isNoDarkness'); // Debug print

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNoDarkness)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'It will not be dark enough at your location tonight for aurora spotting',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDataRow('Sunrise', _sunData?['sunrise'] ?? 'N/A', Colors.white),
                  const SizedBox(height: 8),
                  _buildDataRow('Sunset', _sunData?['sunset'] ?? 'N/A', Colors.white70),
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDataRow('Astro. Twilight Start', astroStart, Colors.white70),
                  const SizedBox(height: 8),
                  _buildDataRow('Astro. Twilight End', astroEnd, Colors.white70),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Astronomical Twilight: Dark enough to see the aurora',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSunInfoHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.withOpacity(0.5)),
          ),
          title: Row(
            children: [
              Icon(Icons.wb_sunny, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Sun & Daylight Guide',
                style: TextStyle(
                  color: Colors.orange,
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
                _buildSunInfoSection(
                  'Astronomical Twilight',
                  'When astronomical twilight falls, the sky is dark enough to see the aurora.',
                  Icons.nightlight_round,
                ),
                const SizedBox(height: 12),
                _buildSunInfoSection(
                  'Day Length',
                  'Total duration of daylight. In very northern or southern areas, it does not get dark enough in the summer to see the aurora.',
                  Icons.timer,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSunInfoSection(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.orange,
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
}

extension TakeLast<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return skip(length - count).toList();
  }
}