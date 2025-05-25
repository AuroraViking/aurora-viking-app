// lib/widgets/spot_aurora_fab.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/aurora_community_service.dart';
import '../screens/spot_aurora_screen.dart';

class SpotAuroraFAB extends StatefulWidget {
  final double bzH;
  final double kp;

  const SpotAuroraFAB({
    super.key,
    required this.bzH,
    required this.kp,
  });

  @override
  State<SpotAuroraFAB> createState() => _SpotAuroraFABState();
}

class _SpotAuroraFABState extends State<SpotAuroraFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start animation if conditions are good
    if (_shouldShowButton()) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(SpotAuroraFAB oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation based on new conditions
    if (_shouldShowButton() && !_animationController.isAnimating) {
      _animationController.repeat(reverse: true);
    } else if (!_shouldShowButton() && _animationController.isAnimating) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _shouldShowButton() {
    return AuroraCommunityService.shouldShowSpotButton(
      bzH: widget.bzH,
      kp: widget.kp,
    );
  }

  Color _getButtonColor() {
    if (widget.bzH > 6 || widget.kp > 6) {
      return Colors.amber; // Exceptional conditions
    } else if (widget.bzH > 4 || widget.kp > 4) {
      return Colors.orange; // Strong conditions
    } else if (widget.bzH > 2 || widget.kp > 2.5) {
      return Colors.tealAccent; // Moderate conditions
    }
    return Colors.tealAccent; // Default
  }

  String _getButtonText() {
    if (widget.bzH > 6 || widget.kp > 6) {
      return '🌟 SPOT AURORA!';
    } else if (widget.bzH > 4 || widget.kp > 4) {
      return '⚡ SPOT AURORA!';
    } else {
      return '🌌 SPOT AURORA!';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowButton()) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: _getButtonColor().withOpacity(_glowAnimation.value * 0.6),
                  blurRadius: 20 * _glowAnimation.value,
                  spreadRadius: 5 * _glowAnimation.value,
                ),
                BoxShadow(
                  color: _getButtonColor().withOpacity(_glowAnimation.value * 0.3),
                  blurRadius: 40 * _glowAnimation.value,
                  spreadRadius: 10 * _glowAnimation.value,
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () => _onSpotAuroraTapped(context),
              backgroundColor: _getButtonColor(),
              foregroundColor: Colors.black,
              elevation: 8,
              heroTag: "spot_aurora_fab",
              icon: const Icon(Icons.camera_alt, size: 20),
              label: Text(
                _getButtonText(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onSpotAuroraTapped(BuildContext context) {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Navigate to spot aurora screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpotAuroraScreen(
          currentBzH: widget.bzH,
          currentKp: widget.kp,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}