// lib/screens/spot_aurora_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_aurora_screen.dart';

class SpotAuroraScreen extends StatefulWidget {
  final double currentBzH;
  final double currentKp;

  const SpotAuroraScreen({
    super.key,
    required this.currentBzH,
    required this.currentKp,
  });

  @override
  State<SpotAuroraScreen> createState() => _SpotAuroraScreenState();
}

class _SpotAuroraScreenState extends State<SpotAuroraScreen> {

  void _openCamera() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraAuroraScreen(
          currentBzH: widget.currentBzH,
          currentKp: widget.currentKp,
        ),
        fullscreenDialog: true,
      ),
    ).then((_) {
      // When returning from camera, close this screen too
      Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Spot Aurora',
          style: TextStyle(
            color: Colors.tealAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Current conditions banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.tealAccent.withOpacity(0.2),
                      Colors.tealAccent.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildConditionItem('BzH', '${widget.currentBzH.toStringAsFixed(1)} nT'),
                    _buildConditionItem('Kp', widget.currentKp.toStringAsFixed(1)),
                    _buildConditionItem('Status', _getConditionsText()),
                  ],
                ),
              ),

              SizedBox(height: 40),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Camera icon with pulsing animation
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.2),
                      duration: Duration(seconds: 2),
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.tealAccent.withOpacity(0.3),
                                  Colors.tealAccent.withOpacity(0.1),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.tealAccent,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.tealAccent.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 60,
                              color: Colors.tealAccent,
                            ),
                          ),
                        );
                      },
                      onEnd: () => setState(() {}), // Trigger rebuild for continuous animation
                    ),

                    SizedBox(height: 32),

                    Text(
                      'Capture the Aurora!',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 16),

                    Text(
                      'Take a photo and share your aurora sighting with the community. Your photo will appear on the map and be available for printing!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 40),

                    // Camera button
                    Container(
                      width: 200,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _openCamera,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: Colors.tealAccent.withOpacity(0.5),
                        ),
                        icon: Icon(Icons.camera_alt, size: 24),
                        label: Text(
                          'OPEN CAMERA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Instructions
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tips_and_updates, color: Colors.amber, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Photography Tips',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          _buildTip('📱', 'Hold your phone steady for 2-3 seconds'),
                          _buildTip('🌙', 'Use night mode if available'),
                          _buildTip('⚡', 'Turn off flash for better results'),
                          _buildTip('🎯', 'Focus on the horizon or aurora'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConditionItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.tealAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String emoji, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(emoji, style: TextStyle(fontSize: 16)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getConditionsText() {
    if (widget.currentBzH > 4.5 || widget.currentKp >= 4.0) {
      return 'Excellent!';
    } else if (widget.currentBzH > 3.0 || widget.currentKp >= 3.0) {
      return 'Good';
    } else if (widget.currentBzH > 1.5 || widget.currentKp >= 2.0) {
      return 'Fair';
    } else {
      return 'Possible';
    }
  }
}