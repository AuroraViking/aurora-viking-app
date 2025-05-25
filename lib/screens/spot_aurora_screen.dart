// lib/screens/spot_aurora_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  int _selectedIntensity = 3;
  String _description = '';
  bool _isSubmitting = false;

  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitSighting() async {
    setState(() {
      _isSubmitting = true;
    });

    // Simulate submission
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.tealAccent, size: 28),
            SizedBox(width: 12),
            Text(
              'Aurora Spotted!',
              style: TextStyle(color: Colors.tealAccent, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Your aurora sighting has been shared with the community. Other users in your area will be notified!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close screen
            },
            child: Text(
              'AWESOME!',
              style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
        child: Column(
          children: [
            // Current conditions
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildConditionItem('BzH', '${widget.currentBzH.toStringAsFixed(1)} nT'),
                  _buildConditionItem('Kp', widget.currentKp.toStringAsFixed(1)),
                  _buildConditionItem('Status', 'Good Conditions'),
                ],
              ),
            ),

            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.tealAccent.withOpacity(0.1),
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.camera_alt,
                      size: 64,
                      color: Colors.tealAccent,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Camera Feature Coming Soon!',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'For now, share your aurora sighting details:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 32),

                    // Intensity selector
                    Text(
                      'Aurora Intensity',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        final intensity = index + 1;
                        final isSelected = intensity == _selectedIntensity;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedIntensity = intensity;
                            });
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.tealAccent : Colors.transparent,
                              border: Border.all(
                                color: Colors.tealAccent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                intensity.toString(),
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.tealAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _getIntensityDescription(_selectedIntensity),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 32),

                    // Description input
                    TextField(
                      controller: _descriptionController,
                      style: TextStyle(color: Colors.white),
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'Describe what you see...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.tealAccent),
                        ),
                        counterStyle: TextStyle(color: Colors.white54),
                      ),
                      onChanged: (value) {
                        _description = value;
                      },
                    ),

                    Spacer(),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitSighting,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 8,
                        ),
                        child: _isSubmitting
                            ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Sharing...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                            : Text(
                          '🌌 SHARE AURORA SIGHTING',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
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

  String _getIntensityDescription(int intensity) {
    switch (intensity) {
      case 1: return '⭐ Faint - Barely visible';
      case 2: return '⭐⭐ Weak - Light green glow';
      case 3: return '⭐⭐⭐ Moderate - Clear aurora';
      case 4: return '⭐⭐⭐⭐ Strong - Bright dancing';
      case 5: return '⭐⭐⭐⭐⭐ EXCEPTIONAL - Incredible!';
      default: return 'Select intensity';
    }
  }
}