import 'package:flutter/material.dart';
import '../services/solar_wind_service.dart';
import '../services/kp_service.dart';
import '../services/kp_forecast_service.dart';
import '../services/aurora_message_service.dart';
import '../widgets/forecast/forecast_chart_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
  }

  double _calculateBzH(List<double> values) {
    if (values.isEmpty) return 0.0;
    final recent = values.length > 60 ? values.takeLast(60) : values;
    final sum = recent.where((bz) => bz < 0).fold(0.0, (acc, bz) => acc + (-bz / 60));
    return double.parse(sum.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final bzH = _calculateBzH(bzValues);
    final combinedMessage = AuroraMessageService.getCombinedAuroraMessage(kp, bzH);
    final statusColor = AuroraMessageService.getStatusColor(kp, bzH);
    final auroraAdvice = AuroraMessageService.getAuroraAdvice(kp, bzH);

    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : SingleChildScrollView(
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
              height: 400, // Fixed height for chart
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
          width: 60,
          child: Text(
            '$label:',
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: isHighlighted ? 12 : 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
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
          ),
        ),
      ],
    );
  }
}

extension TakeLast<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return skip(length - count).toList();
  }
}