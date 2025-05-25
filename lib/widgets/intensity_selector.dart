// lib/widgets/intensity_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IntensitySelector extends StatelessWidget {
  final int selectedIntensity;
  final ValueChanged<int> onIntensityChanged;

  const IntensitySelector({
    super.key,
    required this.selectedIntensity,
    required this.onIntensityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aurora Intensity',
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final intensity = index + 1;
            return _buildIntensityButton(intensity);
          }),
        ),
        SizedBox(height: 8),
        Text(
          _getIntensityDescription(selectedIntensity),
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildIntensityButton(int intensity) {
    final isSelected = intensity == selectedIntensity;
    final color = _getIntensityColor(intensity);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onIntensityChanged(intensity);
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? color : Colors.transparent,
          border: Border.all(
            color: color,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              intensity.toString(),
              style: TextStyle(
                color: isSelected ? Colors.black : color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                intensity,
                    (index) => Icon(
                  Icons.star,
                  size: 4,
                  color: isSelected ? Colors.black54 : color.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getIntensityColor(int intensity) {
    switch (intensity) {
      case 1:
        return Colors.blue[300]!; // Faint - Light blue
      case 2:
        return Colors.green[400]!; // Weak - Green
      case 3:
        return Colors.tealAccent; // Moderate - Teal
      case 4:
        return Colors.orange[400]!; // Strong - Orange
      case 5:
        return Colors.amber; // Exceptional - Gold
      default:
        return Colors.grey;
    }
  }

  String _getIntensityDescription(int intensity) {
    switch (intensity) {
      case 1:
        return '⭐ Faint - Barely visible, camera may pick up better';
      case 2:
        return '⭐⭐ Weak - Visible as light green glow on horizon';
      case 3:
        return '⭐⭐⭐ Moderate - Clear aurora with some movement';
      case 4:
        return '⭐⭐⭐⭐ Strong - Bright aurora with dancing patterns';
      case 5:
        return '⭐⭐⭐⭐⭐ EXCEPTIONAL - Incredible display filling the sky!';
      default:
        return 'Select aurora intensity';
    }
  }
}

// Extended intensity selector with more detailed UI
class DetailedIntensitySelector extends StatefulWidget {
  final int selectedIntensity;
  final ValueChanged<int> onIntensityChanged;
  final bool showDescriptions;

  const DetailedIntensitySelector({
    super.key,
    required this.selectedIntensity,
    required this.onIntensityChanged,
    this.showDescriptions = true,
  });

  @override
  State<DetailedIntensitySelector> createState() => _DetailedIntensitySelectorState();
}

class _DetailedIntensitySelectorState extends State<DetailedIntensitySelector>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      5,
          (index) => AnimationController(
        duration: Duration(milliseconds: 300 + (index * 50)),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.elasticOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _animateSelection(int intensity) {
    // Reset all animations
    for (var controller in _controllers) {
      controller.reset();
    }

    // Animate up to selected intensity
    for (int i = 0; i < intensity; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) {
          _controllers[i].forward();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Aurora Intensity Scale',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Visual intensity scale
          Row(
            children: List.generate(5, (index) {
              final intensity = index + 1;
              return Expanded(
                child: AnimatedBuilder(
                  animation: _animations[index],
                  builder: (context, child) {
                    return Transform.scale(
                      scale: widget.selectedIntensity >= intensity
                          ? _animations[index].value
                          : 0.8,
                      child: _buildDetailedIntensityButton(intensity),
                    );
                  },
                ),
              );
            }),
          ),

          if (widget.showDescriptions) ...[
            SizedBox(height: 16),
            _buildIntensityDescription(),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailedIntensityButton(int intensity) {
    final isSelected = intensity == widget.selectedIntensity;
    final isActive = intensity <= widget.selectedIntensity;
    final color = _getIntensityColor(intensity);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onIntensityChanged(intensity);
        _animateSelection(intensity);
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isActive ? color.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.5),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              intensity.toString(),
              style: TextStyle(
                color: isActive ? color : Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                intensity,
                    (starIndex) => Icon(
                  Icons.star,
                  size: 6,
                  color: isActive ? color : Colors.white30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntensityDescription() {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(widget.selectedIntensity),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getIntensityColor(widget.selectedIntensity).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _getIntensityColor(widget.selectedIntensity).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getIntensityTitle(widget.selectedIntensity),
              style: TextStyle(
                color: _getIntensityColor(widget.selectedIntensity),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _getDetailedDescription(widget.selectedIntensity),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getIntensityColor(int intensity) {
    switch (intensity) {
      case 1: return Colors.blue[300]!;
      case 2: return Colors.green[400]!;
      case 3: return Colors.tealAccent;
      case 4: return Colors.orange[400]!;
      case 5: return Colors.amber;
      default: return Colors.grey;
    }
  }

  String _getIntensityTitle(int intensity) {
    switch (intensity) {
      case 1: return '⭐ Faint Aurora';
      case 2: return '⭐⭐ Weak Aurora';
      case 3: return '⭐⭐⭐ Moderate Aurora';
      case 4: return '⭐⭐⭐⭐ Strong Aurora';
      case 5: return '⭐⭐⭐⭐⭐ EXCEPTIONAL Aurora';
      default: return 'Select Intensity';
    }
  }

  String _getDetailedDescription(int intensity) {
    switch (intensity) {
      case 1:
        return 'Barely visible to the naked eye. May appear as a faint green glow on the horizon. Camera often picks up more detail than what you can see.';
      case 2:
        return 'Visible as a light green glow or arc on the northern horizon. Some movement may be detected. Good for photography.';
      case 3:
        return 'Clear aurora with defined structure. Green curtains or arcs with some movement. Easily visible and photogenic.';
      case 4:
        return 'Bright aurora with active dancing patterns. Multiple colors possible. Overhead activity likely. Excellent conditions!';
      case 5:
        return 'Incredible display filling much of the sky! Rapid movement, multiple colors, coronas possible. Once-in-a-lifetime experience!';
      default:
        return 'Select the intensity level that best matches what you\'re seeing.';
    }
  }
}

// Compact intensity selector for quick selection
class CompactIntensitySelector extends StatelessWidget {
  final int selectedIntensity;
  final ValueChanged<int> onIntensityChanged;

  const CompactIntensitySelector({
    super.key,
    required this.selectedIntensity,
    required this.onIntensityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Intensity:',
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          children: List.generate(5, (index) {
            final intensity = index + 1;
            final isSelected = intensity == selectedIntensity;
            final isActive = intensity <= selectedIntensity;

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onIntensityChanged(intensity);
              },
              child: Container(
                margin: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.star,
                  size: 24,
                  color: isActive
                      ? _getIntensityColor(intensity)
                      : Colors.white30,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Color _getIntensityColor(int intensity) {
    switch (intensity) {
      case 1: return Colors.blue[300]!;
      case 2: return Colors.green[400]!;
      case 3: return Colors.tealAccent;
      case 4: return Colors.orange[400]!;
      case 5: return Colors.amber;
      default: return Colors.grey;
    }
  }
}