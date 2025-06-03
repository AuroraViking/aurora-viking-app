import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math';
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

class _AuroraPowerChartState extends State<AuroraPowerChart> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;
  List<AuroraPowerPoint> _currentData = [];

  @override
  void initState() {
    super.initState();
    _currentData = widget.data;
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 0.9).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    
    // Listen to data updates
    widget.service.dataStream.listen((newData) {
      if (mounted) {
        setState(() {
          _currentData = newData;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentData.isEmpty) return const Center(child: Text("No data"));

    final minTime = _currentData.first.time.millisecondsSinceEpoch.toDouble();
    final maxTime = _currentData.last.time.millisecondsSinceEpoch.toDouble();
    final maxPower = _currentData.map((e) => e.power).reduce(max);
    final isSubstorm = maxPower > 100;

    // Calculate time interval, ensuring it's not zero
    final timeRange = maxTime - minTime;
    final timeInterval = timeRange > 0 ? (timeRange / 4).toDouble() : 3600000.0; // Default to 1 hour if all points are at same time

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              if (isSubstorm)
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(_pulse.value),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: max(120, maxPower + 10),
              minX: minTime,
              maxX: maxTime,
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 60,
                    interval: 20,
                    getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${value.toInt()} GW',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: timeInterval,
                    getTitlesWidget: (value, _) {
                      final time = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 20,
                getDrawingHorizontalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1),
                getDrawingVerticalLine: (_) => FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
              ),
              backgroundColor: const Color(0xFF0A0D1C),
              lineBarsData: [
                LineChartBarData(
                  isCurved: true,
                  barWidth: 4,
                  color: Colors.cyanAccent.withOpacity(_pulse.value),
                  dotData: FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.cyan.withOpacity(0.3),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  spots: _currentData.map((p) {
                    return FlSpot(
                      p.time.millisecondsSinceEpoch.toDouble(),
                      p.power,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 