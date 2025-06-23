import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../services/auroral_power_service.dart';

class AuroraPowerPoint {
  final DateTime time;
  final double power;

  AuroraPowerPoint(this.time, this.power);
}

class AuroraPowerChart extends StatefulWidget {
  final List<AuroraPowerPoint> data;
  final AuroralPowerService service;

  const AuroraPowerChart({
    super.key,
    required this.data,
    required this.service,
  });

  @override
  State<AuroraPowerChart> createState() => _AuroraPowerChartState();
}

class _AuroraPowerChartState extends State<AuroraPowerChart> {
  List<AuroraPowerPoint> _data = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('🎨 Chart initState: initial data length = ${widget.data.length}');
    _data = widget.data;
    _isLoading = widget.data.isEmpty;

    // Listen for updates
    widget.service.auroralPowerStream.listen((newData) {
      print('🎨 Chart received stream data with keys: ${newData.keys}');
      if (mounted && newData.containsKey('historicalData')) {
        final historicalData = newData['historicalData'];
        if (historicalData is List<AuroraPowerPoint>) {
          print('🎨 Updating chart with ${historicalData.length} data points');
          setState(() {
            _data = historicalData;
            _isLoading = false;
          });
        } else {
          print('❌ Historical data is wrong type: ${historicalData.runtimeType}');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Chart build: isLoading=$_isLoading, data.length=${_data.length}');

    if (_isLoading) {
      print('📊 Chart showing loading because: isLoading=$_isLoading');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.tealAccent,
            ),
            SizedBox(height: 16),
            Text(
              'Loading auroral power data...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_data.isEmpty) {
      return Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: Text(
            'Waiting for auroral power data...',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    print('📊 Chart building actual chart with ${_data.length} data points');

    // Sort data by time (oldest to newest)
    final sortedData = List<AuroraPowerPoint>.from(_data)
      ..sort((a, b) => a.time.compareTo(b.time));

    // Calculate Y-axis limits with padding (FIXED TYPE ISSUES)
    final maxPower = sortedData.map((point) => point.power).reduce((a, b) => a > b ? a : b);
    final minPower = sortedData.map((point) => point.power).reduce((a, b) => a < b ? a : b);
    final yMax = maxPower + (maxPower * 0.2); // 20% padding
    final yMin = (minPower - (minPower * 0.2)).clamp(0.0, double.infinity); // Safe clamp

    print('📊 Chart Y-axis: min=$minPower, max=$maxPower, chart min=$yMin, chart max=$yMax');

    // Calculate grid interval
    final range = yMax - yMin;
    final gridInterval = range / 5; // 5 grid lines

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: gridInterval,
            verticalInterval: (sortedData.length / 10).ceil().toDouble(),
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.white.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.white.withOpacity(0.1),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (sortedData.length / 6).ceil().toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sortedData.length) return const Text('');
                  final time = sortedData[index].time;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: gridInterval,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          minX: 0,
          maxX: (sortedData.length - 1).toDouble(),
          minY: yMin,
          maxY: yMax,
          lineBarsData: [
            LineChartBarData(
              spots: sortedData.asMap().entries.map((entry) {
                return FlSpot(entry.key.toDouble(), entry.value.power);
              }).toList(),
              isCurved: true,
              gradient: LinearGradient(
                colors: [
                  Colors.cyan.withOpacity(0.5),
                  Colors.cyan,
                ],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.cyan.withOpacity(0.3),
                    Colors.cyan.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final index = barSpot.x.toInt();
                  if (index < 0 || index >= sortedData.length) return null;
                  final data = sortedData[index];
                  return LineTooltipItem(
                    '${data.power.toStringAsFixed(2)} GW\n${data.time.hour}:${data.time.minute.toString().padLeft(2, '0')}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  );
                }).whereType<LineTooltipItem>().toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}