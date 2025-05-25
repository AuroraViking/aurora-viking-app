import 'package:flutter/material.dart';

class ChartGlowContainer extends StatelessWidget {
  final Widget child;
  final bool isActive;

  const ChartGlowContainer({required this.child, required this.isActive, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        boxShadow: isActive
            ? [
          BoxShadow(
            color: Colors.amberAccent.withAlpha((0.4 * 255).toInt()), // ~0.4
            blurRadius: 50,
            spreadRadius: 5,
          )
        ]
            : [],
      ),
      child: child,
    );
  }
}
