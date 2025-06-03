// lib/screens/spot_aurora_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'camera_aurora_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_service.dart';
import '../models/aurora_sighting.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpotAuroraScreen extends StatefulWidget {
  final double currentBzH;
  final double currentKp;
  final bool photoRequired;

  const SpotAuroraScreen({
    super.key,
    required this.currentBzH,
    required this.currentKp,
    this.photoRequired = true,
  });

  @override
  State<SpotAuroraScreen> createState() => _SpotAuroraScreenState();
}

class _SpotAuroraScreenState extends State<SpotAuroraScreen> {
  final ImagePicker _picker = ImagePicker();
  int _selectedIntensity = 0;

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

  Future<void> _uploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (!mounted) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraAuroraScreen(
              currentBzH: widget.currentBzH,
              currentKp: widget.currentKp,
              initialImagePath: image.path,
            ),
            fullscreenDialog: true,
          ),
        ).then((_) {
          // When returning from camera, close this screen too
          Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Spot Aurora',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'How would you like to share your aurora sighting?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildOptionButton(
                  icon: Icons.camera_alt,
                  label: 'Take Photo',
                  onTap: _openCamera,
                ),
                const SizedBox(width: 24),
                _buildOptionButton(
                  icon: Icons.upload_file,
                  label: 'Upload Photo',
                  onTap: _uploadImage,
                ),
                const SizedBox(width: 24),
                _buildOptionButton(
                  icon: Icons.location_on,
                  label: 'Just Location',
                  onTap: () {
                    _showLocationDescriptionDialog();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Colors.tealAccent),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationDescriptionDialog() async {
    final TextEditingController descriptionController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate Aurora Intensity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _selectedIntensity ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedIntensity = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Enter a description of the aurora you spotted...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop({
                'description': descriptionController.text,
                'intensity': _selectedIntensity,
              }),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _addLocationOnlySighting(result['description'], result['intensity']);
    }
  }

  Future<void> _addLocationOnlySighting(String description, int intensity) async {
    try {
      final position = await _getCurrentPosition();
      final sighting = AuroraSighting(
        id: '',
        userId: FirebaseService().currentUser?.uid ?? '',
        userName: FirebaseService().currentUser?.displayName ?? 'Anonymous',
        location: GeoPoint(position.latitude, position.longitude),
        locationName: 'Current Location', // TODO: Get location name from coordinates
        timestamp: DateTime.now(),
        photoUrls: [],
        description: description,
        weather: {
          'bzH': widget.currentBzH,
          'kp': widget.currentKp,
        },
        intensity: intensity,
        confirmations: 0,
        confirmedByUsers: [],
        isVerified: false,
        commentCount: 0,
      );

      await FirebaseService().addAuroraSighting(sighting);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location-only sighting added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add location-only sighting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Position> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      throw Exception('Failed to get current position: $e');
    }
  }
}