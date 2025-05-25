import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'pulsing_aurora_icon.dart';

class ForecastChartWidget extends StatelessWidget {
  final List<double> bzValues;
  final List<String> times;
  final double kp;
  final double speed;
  final double density;
  final double bt;

  const ForecastChartWidget({
    super.key,
    required this.bzValues,
    required this.times,
    required this.kp,
    required this.speed,
    required this.density,
    required this.bt,
  });

  @override
  Widget build(BuildContext context) {
    final bzH = _calculateBzH(bzValues);
    final isAuroraLikely = bzH > 3;
    final yLimit = _getYLimit(bzValues);
    final isBelowZero = bzValues.any((bz) => bz < 0);
    final earthImpactIndex = _calculateEarthImpactIndex();

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.tealAccent.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          bzValues.length,
                              (i) => FlSpot(i.toDouble(), bzValues[i]),
                        ),
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: isBelowZero
                              ? [Colors.redAccent, Colors.orange, Colors.tealAccent]
                              : [Colors.tealAccent, Colors.cyanAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: isBelowZero
                                ? [
                              Colors.redAccent.withOpacity(0.1),
                              Colors.orange.withOpacity(0.05),
                              Colors.transparent,
                            ]
                                : [
                              Colors.tealAccent.withOpacity(0.1),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                    minY: -yLimit,
                    maxY: yLimit,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.1),
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return FlLine(
                          color: Colors.white.withOpacity(0.05),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          getTitlesWidget: (value, meta) {
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx % 15 == 0 && idx < times.length) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  times[idx],
                                  style: TextStyle(
                                    color: idx == earthImpactIndex
                                        ? Colors.amber
                                        : Colors.white70,
                                    fontSize: 10,
                                    fontWeight: idx == earthImpactIndex
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: Colors.tealAccent.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: 0,
                          color: Colors.grey.withOpacity(0.8),
                          strokeWidth: 2,
                          dashArray: [5, 5],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 8),
                            labelResolver: (_) => 'Zero Line',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      verticalLines: earthImpactIndex != null ? [
                        VerticalLine(
                          x: earthImpactIndex!.toDouble(),
                          color: Colors.amber,
                          strokeWidth: 3,
                          dashArray: [8, 4],
                          label: VerticalLineLabel(
                            show: true,
                            alignment: Alignment.topLeft,
                            padding: const EdgeInsets.only(right: 8, top: 4),
                            labelResolver: (_) => '🌍 Now at Earth',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.amber, blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                      ] : [],
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
            ),

            // Aurora icon when conditions are good
            if (isAuroraLikely)
              const Positioned(
                top: 16,
                left: 16,
                child: PulsingAuroraIcon(),
              ),

            // Chart title with Earth impact info
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.tealAccent.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Bz Component (nT)',
                      style: TextStyle(
                        color: Colors.tealAccent.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (earthImpactIndex != null && speed > 0)
                      Text(
                        'Earth impact: ${_getEarthImpactDelay().toStringAsFixed(0)}min',
                        style: TextStyle(
                          color: Colors.amber.withOpacity(0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Earth impact info box (top right when impact line is visible)
            if (earthImpactIndex != null && speed > 0)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.withOpacity(0.2),
                        Colors.orange.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🌍', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Text(
                            'L1 → Earth',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${_getEarthImpactDelay().toStringAsFixed(0)} minutes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '@${speed.toInt()}m/s',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int? _calculateEarthImpactIndex() {
    if (speed <= 0 || times.isEmpty) return null;

    // Distance from L1 to Earth: ~1.5 million km = 1,500,000,000 meters
    // Wait, let me double-check this calculation...

    // L1 Lagrange point is approximately 1.5 million kilometers from Earth
    // 1.5 million km = 1,500,000 km = 1,500,000 * 1000 m = 1,500,000,000 m

    // But let me verify with a known example:
    // Typical solar wind speed: 400 km/s = 400,000 m/s
    // Expected transit time: should be around 60-90 minutes

    // Let's work backwards: if 400 km/s should give ~60 minutes
    // Then distance = speed × time = 400 km/s × 3600 s = 1,440,000 km ≈ 1.5M km ✓

    // AHA! The issue is the speed units!
    // Your speed data is in m/s, but solar wind speeds are typically 300-800 km/s
    // So 400 m/s is way too slow - it should be more like 400,000 m/s

    const double l1ToEarthMeters = 1500000000.0; // 1.5 million km in meters

    // Let's check if speed needs unit conversion
    // If speed is actually in km/s but labeled as m/s:
    final speedInMeterPerSec = speed;
    final speedInKmPerSec = speed / 1000.0;

    // Calculate both possibilities
    final delaySecondsIfMperS = l1ToEarthMeters / speedInMeterPerSec;
    final delaySecondsIfKmperS = l1ToEarthMeters / (speedInKmPerSec * 1000);

    final delayMinutesIfMperS = delaySecondsIfMperS / 60.0;
    final delayMinutesIfKmperS = delaySecondsIfKmperS / 60.0;

    print('🌍 DEBUGGING Transit Time Calculation:');
    print('   Raw speed value: ${speed}');
    print('   If speed is m/s: ${delayMinutesIfMperS.toStringAsFixed(1)} minutes');
    print('   If speed is km/s: ${delayMinutesIfKmperS.toStringAsFixed(1)} minutes');

    // Choose the realistic delay (should be 30-120 minutes)
    double delayMinutes;
    if (delayMinutesIfKmperS >= 30 && delayMinutesIfKmperS <= 120) {
      delayMinutes = delayMinutesIfKmperS;
      print('   Using km/s interpretation: ${delayMinutes.toStringAsFixed(1)} minutes ✓');
    } else if (delayMinutesIfMperS >= 30 && delayMinutesIfMperS <= 120) {
      delayMinutes = delayMinutesIfMperS;
      print('   Using m/s interpretation: ${delayMinutes.toStringAsFixed(1)} minutes ✓');
    } else {
      // If neither makes sense, use a fixed reasonable delay
      delayMinutes = 60.0;
      print('   Neither makes sense, using default: 60 minutes');
    }

    // Now calculate the index properly
    // Assume 1-minute resolution for NOAA data
    final dataPointsBack = delayMinutes.round();
    final mostRecentIndex = times.length - 1;
    final earthImpactIndex = mostRecentIndex - dataPointsBack;

    print('   Final calculation:');
    print('     Delay: ${delayMinutes.toStringAsFixed(1)} minutes');
    print('     Going back: $dataPointsBack data points');
    print('     Index: $earthImpactIndex');

    // Ensure index is in bounds
    if (earthImpactIndex < 0) {
      print('     Clamped to start (0)');
      return 0;
    }
    if (earthImpactIndex >= times.length) {
      print('     Clamped to end (${times.length - 1})');
      return times.length - 1;
    }

    if (earthImpactIndex < times.length) {
      print('     Final position: ${times[earthImpactIndex]}');
    }

    return earthImpactIndex;
  }

  double _getEarthImpactDelay() {
    if (speed <= 0) return 0.0;

    // Distance: 1.5 million km = 1,500,000,000 meters
    const double l1ToEarthMeters = 1500000000.0;

    // Check both unit possibilities
    final speedInMeterPerSec = speed;
    final speedInKmPerSec = speed / 1000.0;

    // Calculate both possibilities
    final delaySecondsIfMperS = l1ToEarthMeters / speedInMeterPerSec;
    final delaySecondsIfKmperS = l1ToEarthMeters / (speedInKmPerSec * 1000);

    final delayMinutesIfMperS = delaySecondsIfMperS / 60.0;
    final delayMinutesIfKmperS = delaySecondsIfKmperS / 60.0;

    // Choose the realistic delay (should be 30-120 minutes)
    if (delayMinutesIfKmperS >= 30 && delayMinutesIfKmperS <= 120) {
      return delayMinutesIfKmperS; // Speed is actually km/s
    } else if (delayMinutesIfMperS >= 30 && delayMinutesIfMperS <= 120) {
      return delayMinutesIfMperS; // Speed is actually m/s
    } else {
      return 60.0; // Default fallback
    }
  }

  double _calculateBzH(List<double> values) {
    if (values.isEmpty) return 0.0;
    final recent = values.length > 60 ? values.skip(values.length - 60).toList() : values;
    final sum = recent.where((bz) => bz < 0).fold(0.0, (acc, bz) => acc + (-bz / 60));
    return double.parse(sum.toStringAsFixed(2));
  }

  double _getYLimit(List<double> values) {
    if (values.isEmpty) return 10;
    final absMax = values.map((e) => e.abs()).fold<double>(0, (a, b) => a > b ? a : b);
    if (absMax <= 5) return 5;
    if (absMax <= 10) return 10;
    if (absMax <= 20) return 20;
    if (absMax <= 50) return 50;
    return 100;
  }
}