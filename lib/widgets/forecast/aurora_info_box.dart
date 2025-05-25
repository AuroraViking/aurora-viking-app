// lib/widgets/forecast/aurora_info_box.dart
import 'package:flutter/material.dart';

class AuroraInfoBox extends StatelessWidget {
  final double bzH;

  const AuroraInfoBox({super.key, required this.bzH});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BzH: $bzH nT',
            style: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.cyanAccent, blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 6),
          const Text('Kp: N/A', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Speed: --- km/s', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Density: --- /cm³', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Bt: --- nT', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}
