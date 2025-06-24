import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'pulsing_aurora_icon.dart';
import 'chart_background_painter.dart';

class ForecastChartWidget extends StatefulWidget {
  final List<double> bzValues;
  final List<String> times;
  final double kp;
  final double speed;
  final double density;
  final double bt;
  final List<double> btValues;

  const ForecastChartWidget({
    super.key,
    required this.bzValues,
    required this.times,
    required this.kp,
    required this.speed,
    required this.density,
    required this.bt,
    required this.btValues,
  });

  @override
  State<ForecastChartWidget> createState() => _ForecastChartWidgetState();
}

class _ForecastChartWidgetState extends State<ForecastChartWidget> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double _getMaxBz() {
    if (widget.bzValues.isEmpty) return 0;
    return widget.bzValues.reduce((a, b) => a.abs() > b.abs() ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final bzH = _calculateBzH(widget.bzValues);
    final isAuroraLikely = bzH > 3;
    final yLimit = _getYLimit(widget.bzValues);
    final isBelowZero = widget.bzValues.any((bz) => bz < 0);
    final earthImpactIndex = _calculateEarthImpactIndex();
    final maxBz = _getMaxBz();

    // Adjust pulse speed and intensity based on BzH value
    if (bzH > 1) {
      final speed = 1500 / (bzH * 0.5); // Faster pulse for higher BzH
      _pulseController.duration = Duration(milliseconds: speed.toInt());
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
    }

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
                child: Stack(
                  children: [
                    // Chart
                    LineChart(
                      LineChartData(
                        lineBarsData: [
                          // Bz line
                          LineChartBarData(
                            spots: List.generate(
                              widget.bzValues.length,
                              (i) => FlSpot(i.toDouble(), widget.bzValues[i]),
                            ),
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: isBelowZero
                                  ? [
                                      const Color(0xFF4ECDC4), // Teal
                                      const Color(0xFF4ECDC4).withOpacity(0.7), // Faded teal
                                    ]
                                  : [
                                      const Color(0xFF4ECDC4), // Teal
                                      const Color(0xFF45B7D1), // Blue
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: isBelowZero
                                    ? [
                                        const Color(0xFF4ECDC4).withOpacity(0.2),
                                        Colors.transparent,
                                      ]
                                    : [
                                        const Color(0xFF4ECDC4).withOpacity(0.1),
                                        Colors.transparent,
                                      ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            shadow: Shadow(
                              color: const Color(0xFF4ECDC4).withOpacity(
                                0.7 + (_pulseAnimation.value * 0.3 * (bzH / 3))
                              ),
                              blurRadius: 12 + (_pulseAnimation.value * 12 * (bzH / 3)),
                              offset: const Offset(0, 2),
                            ),
                          ),
                          // Bt line (positive)
                          LineChartBarData(
                            spots: List.generate(
                              widget.btValues.length,
                              (i) => FlSpot(i.toDouble(), widget.btValues[i]),
                            ),
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.withOpacity(0.9),
                                Colors.orange.withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            shadow: Shadow(
                              color: Colors.amber.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          // Bt line (negative)
                          LineChartBarData(
                            spots: List.generate(
                              widget.btValues.length,
                              (i) => FlSpot(i.toDouble(), -widget.btValues[i]),
                            ),
                            isCurved: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.withOpacity(0.9),
                                Colors.orange.withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            shadow: Shadow(
                              color: Colors.amber.withOpacity(0.5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.amber.withOpacity(0.1),
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
                                if (idx % 15 == 0 && idx < widget.times.length) {
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      widget.times[idx],
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
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                              x: earthImpactIndex.toDouble(),
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
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBorder: BorderSide(
                              color: Colors.tealAccent.withOpacity(0.3),
                              width: 1,
                            ),
                            tooltipRoundedRadius: 8,
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItems: (List<LineBarSpot> touchedSpots) {
                              return touchedSpots.map((spot) {
                                final index = spot.x.toInt();
                                if (index >= widget.times.length) return null;
                                
                                String value;
                                Color color;
                                if (spot.barIndex == 0) {
                                  value = 'Bz: ${spot.y.toStringAsFixed(2)} nT';
                                  color = const Color(0xFF4ECDC4);
                                } else if (spot.barIndex == 2) { // Only show Bt for negative line
                                  value = 'Bt: ${spot.y.abs().toStringAsFixed(2)} nT';
                                  color = Colors.amber;
                                } else {
                                  return null; // Don't show tooltip for positive Bt line
                                }
                                
                                return LineTooltipItem(
                                  value,
                                  TextStyle(
                                    color: color,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                          handleBuiltInTouches: true,
                          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                            // Handle touch events if needed
                          },
                        ),
                      ),
                    ),
                  ],
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
                    if (earthImpactIndex != null && widget.speed > 0)
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
            if (earthImpactIndex != null && widget.speed > 0)
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
                      const Row(
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
                      const SizedBox(height: 2),
                      Text(
                        '${_getEarthImpactDelay().toStringAsFixed(0)} minutes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '@${widget.speed.toInt()}km/s',
                        style: const TextStyle(
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
    if (widget.speed <= 0 || widget.times.isEmpty) return null;

    // Simple formula: 1,500,000 / speed / 60 = minutes
    const double l1ToEarthKm = 1500000.0; // 1.5 million km
    final delayMinutes = l1ToEarthKm / widget.speed / 60.0;

    // Calculate index (assuming 1-minute data resolution)
    final dataPointsBack = delayMinutes.round();
    final mostRecentIndex = widget.times.length - 1;
    final earthImpactIndex = mostRecentIndex - dataPointsBack;

    // Ensure index is in bounds
    if (earthImpactIndex < 0) return 0;
    if (earthImpactIndex >= widget.times.length) return widget.times.length - 1;

    return earthImpactIndex;
  }

  double _getEarthImpactDelay() {
    if (widget.speed <= 0) return 0.0;

    // Simple formula: 1,500,000 / speed / 60 = minutes
    const double l1ToEarthKm = 1500000.0; // 1.5 million km
    return l1ToEarthKm / widget.speed / 60.0;
  }

  double _calculateBzH(List<double> values) {
    if (values.isEmpty) return 0.0;
    final recent = values.length > 60 ? values.skip(values.length - 60).toList() : values;
    final sum = recent.where((bz) => bz < 0).fold(0.0, (acc, bz) => acc + (-bz / 60));
    return double.parse(sum.toStringAsFixed(2));
  }

  double _getYLimit(List<double> values) {
    // Use Bt values for autoscaling instead of Bz
    if (widget.btValues.isEmpty) return 10;
    final absMax = widget.btValues.map((e) => e.abs()).fold<double>(0, (a, b) => a > b ? a : b);
    if (absMax <= 5) return 5;
    if (absMax <= 10) return 10;
    if (absMax <= 20) return 20;
    if (absMax <= 50) return 50;
    return 100;
  }
}