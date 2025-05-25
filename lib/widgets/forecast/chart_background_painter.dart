import 'package:flutter/material.dart';

class ChartBackgroundPainter extends CustomPainter {
  final double chartHeight;
  final double minY;
  final double maxY;

  ChartBackgroundPainter({
    required this.chartHeight,
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final zeroY = _calculateZeroY(size.height);

    final greenPaint = Paint()..color = const Color.fromARGB(80, 0, 255, 100); // translucent green
    final redPaint = Paint()..color = const Color.fromARGB(80, 255, 60, 60);   // translucent red

    // Fill above zero line
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, zeroY), greenPaint);

    // Fill below zero line
    canvas.drawRect(Rect.fromLTWH(0, zeroY, size.width, size.height - zeroY), redPaint);
  }

  double _calculateZeroY(double height) {
    final range = maxY - minY;
    if (range == 0) return height / 2;
    final zeroRelative = (maxY - 0) / range;
    return zeroRelative * height;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
