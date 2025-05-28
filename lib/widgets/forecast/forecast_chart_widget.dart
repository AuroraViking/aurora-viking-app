import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'pulsing_aurora_icon.dart';

class ForecastChartWidget extends StatelessWidget {
  final List<double> bzValues;
  final List<String> times;
  final double kp;
  final double speed;
  final double density;

  const ForecastChartWidget({
    super.key,
    required this.bzValues,
    required this.times,
    required this.kp,
    required this.speed,
    required this.density,
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
                        '@${speed.toInt()}km/s',
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

    // Simple formula: 1,500,000 / speed / 60 = minutes
    const double l1ToEarthKm = 1500000.0; // 1.5 million km
    final delayMinutes = l1ToEarthKm / speed / 60.0;

    // Calculate index (assuming 1-minute data resolution)
    final dataPointsBack = delayMinutes.round();
    final mostRecentIndex = times.length - 1;
    final earthImpactIndex = mostRecentIndex - dataPointsBack;

    // Ensure index is in bounds
    if (earthImpactIndex < 0) return 0;
    if (earthImpactIndex >= times.length) return times.length - 1;

    return earthImpactIndex;
  }

  double _getEarthImpactDelay() {
    if (speed <= 0) return 0.0;

    // Simple formula: 1,500,000 / speed / 60 = minutes
    const double l1ToEarthKm = 1500000.0; // 1.5 million km
    return l1ToEarthKm / speed / 60.0;
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