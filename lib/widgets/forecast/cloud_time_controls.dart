import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CloudTimeControls extends StatelessWidget {
  final double timeOffset;
  final Function(double) onTimeChanged;

  const CloudTimeControls({
    super.key,
    required this.timeOffset,
    required this.onTimeChanged,
  });

  String _getTimeLabel() {
    final now = DateTime.now();
    final time = now.subtract(Duration(hours: timeOffset.toInt()));
    return DateFormat('HH:mm').format(time);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.tealAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3 hours ago',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                _getTimeLabel(),
                style: const TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Now',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.tealAccent,
              inactiveTrackColor: Colors.tealAccent.withOpacity(0.3),
              thumbColor: Colors.tealAccent,
              overlayColor: Colors.tealAccent.withOpacity(0.2),
            ),
            child: Slider(
              value: timeOffset,
              min: 0,
              max: 3,
              divisions: 6,
              label: '${timeOffset.toStringAsFixed(1)}h ago',
              onChanged: onTimeChanged,
            ),
          ),
        ],
      ),
    );
  }
} 