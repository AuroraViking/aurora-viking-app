// lib/screens/camera_aurora_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import '../services/firebase_service.dart';
import '../widgets/intensity_selector.dart';
import '../models/aurora_sighting.dart';
import '../services/solar_wind_service.dart';
import '../services/kp_service.dart';
import '../services/aurora_message_service.dart';

class CameraAuroraScreen extends StatefulWidget {
  final double currentBzH;
  final double currentKp;
  final String? initialImagePath;

  const CameraAuroraScreen({
    super.key,
    required this.currentBzH,
    required this.currentKp,
    this.initialImagePath,
  });

  @override
  State<CameraAuroraScreen> createState() => _CameraAuroraScreenState();
}

class _CameraAuroraScreenState extends State<CameraAuroraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {

  // Location variables
  Position? _currentPosition;
  String _locationName = 'Unknown Location';

  // Aurora data variables
  double _currentBzH = 0.0;
  double _currentKp = 0.0;
  double _solarWindSpeed = 0.0;
  double _solarWindDensity = 0.0;
  Timer? _auroraDataTimer;

  // Aurora sighting variables
  int _selectedIntensity = 3;
  String _description = '';
  File? _capturedPhoto;
  bool _isSubmitting = false;

  // UI variables
  bool _showCaptureUI = false;
  bool _showDetailsForm = false;
  late AnimationController _pulseController;
  late AnimationController _slideController;

  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  // Camera variables
  bool _isPhotoTaken = false;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Check if an initial image was provided (from gallery upload)
    if (widget.initialImagePath != null) {
      _isPhotoTaken = true;
      _capturedPhoto = File(widget.initialImagePath!);
      _photoPath = widget.initialImagePath;
      // For uploaded images, we don't need the slide animation
      // The details form will show directly in the main content area
    }

    _getCurrentLocation();
    _fetchAuroraData();
    
    // Set up timer to refresh aurora data every 5 minutes
    _auroraDataTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _fetchAuroraData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _slideController.dispose();
    _descriptionController.dispose();
    _auroraDataTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // Handle inactive state if needed
    } else if (state == AppLifecycleState.resumed) {
      // Handle resumed state if needed
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationName = 'Location services disabled';
        });
        return;
      }

      // Check for location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationName = 'Location permission denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationName = 'Location permission permanently denied';
        });
        return;
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get address from coordinates
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        setState(() {
          _currentPosition = position;
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final locality = place.locality ?? '';
            final subAdminArea = place.subAdministrativeArea ?? '';
            final adminArea = place.administrativeArea ?? '';
            final country = place.country ?? '';
            
            // Build location name with available information
            final locationParts = <String>[];
            if (locality.isNotEmpty) locationParts.add(locality);
            if (subAdminArea.isNotEmpty && subAdminArea != locality) locationParts.add(subAdminArea);
            if (adminArea.isNotEmpty && adminArea != locality && adminArea != subAdminArea) locationParts.add(adminArea);
            if (country.isNotEmpty) locationParts.add(country);
            
            _locationName = locationParts.isNotEmpty ? locationParts.join(', ') : 'Location found';
          } else {
            _locationName = 'Location found';
          }
        });
      } catch (e) {
        print('Geocoding error: $e');
        setState(() {
          _currentPosition = position;
          _locationName = 'Location found';
        });
      }

    } catch (e) {
      print('Location error: $e');
      setState(() {
        _locationName = 'Location unavailable: ${e.toString()}';
      });
    }
  }

  Future<void> _submitAuroraSighting() async {
    if (_capturedPhoto == null || _currentPosition == null) {
      _showErrorDialog('Please capture a photo and ensure location is available');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      HapticFeedback.mediumImpact();

      print('📸 Submitting aurora sighting...');
      print('   Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      print('   Photo: ${_capturedPhoto!.path}');
      print('   Intensity: $_selectedIntensity');

      // Submit to Firebase
      final sightingId = await _firebaseService.submitAuroraSighting(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _locationName,
        intensity: _selectedIntensity,
        description: _description.isNotEmpty ? _description : 'Aurora sighting',
        photoFile: _capturedPhoto,
        bzH: _currentBzH,
        kp: _currentKp,
        solarWindSpeed: _solarWindSpeed,
      );

      print('✅ Sighting submitted with ID: $sightingId');

      if (sightingId != null) {
        _showSuccessDialog();
      } else {
        _showErrorDialog('Failed to submit aurora sighting. Please try again.');
      }

    } catch (e) {
      print('❌ Error submitting sighting: $e');
      _showErrorDialog('Error submitting sighting: ${e.toString()}');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _retakePhoto() {
    // If we came from an uploaded image, just go back instead of showing camera
    if (widget.initialImagePath != null) {
      Navigator.of(context).pop();
      return;
    }
    
    setState(() {
      _capturedPhoto = null;
      _showDetailsForm = false;
      _isPhotoTaken = false;
    });
    _slideController.reverse();
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Permission Required', style: TextStyle(color: Colors.tealAccent)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.tealAccent)),
          ),
        ],
      ),
    );
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
              'Aurora Shared!',
              style: TextStyle(color: Colors.tealAccent, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🌌 Your aurora sighting has been shared with the community! Other aurora hunters in your area will be notified.',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.print, color: Colors.tealAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your photo is now available in the Print Shop!',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close camera screen
            },
            child: Text(
              'VIEW COMMUNITY',
              style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAuroraData() async {
    try {
      // Fetch Bz history and calculate BzH
      final bzHistory = await SolarWindService.fetchBzHistory();
      final bzH = _calculateBzH(bzHistory.bzValues);
      
      // Fetch current Kp
      final kp = await KpService.fetchCurrentKp();
      
      // Fetch solar wind data
      final solarWindData = await SolarWindService.fetchData();

      setState(() {
        _currentBzH = bzH;
        _currentKp = kp;
        _solarWindSpeed = solarWindData.speed;
        _solarWindDensity = solarWindData.density;
      });
    } catch (e) {
      print('Error fetching aurora data: $e');
    }
  }

  double _calculateBzH(List<double> values) {
    if (values.isEmpty) return 0.0;
    final recent = values.length > 60 ? values.sublist(values.length - 60) : values;
    final sum = recent.where((bz) => bz < 0).fold(0.0, (acc, bz) => acc + (-bz / 60));
    return double.parse(sum.toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Only show camera if no initial image was provided and photo hasn't been taken
          if (!_isPhotoTaken && widget.initialImagePath == null)
            Positioned.fill(
              child: CameraAwesomeBuilder.awesome(
                saveConfig: SaveConfig.photo(),
                onMediaTap: (mediaCapture) {
                  mediaCapture.captureRequest.when(
                    single: (single) {
                      setState(() {
                        _isPhotoTaken = true;
                        _photoPath = single.file?.path;
                        // FIX: Set _capturedPhoto so the image appears in the details form
                        if (single.file != null) {
                          _capturedPhoto = File(single.file!.path);
                        }
                      });
                    },
                    multiple: (multiple) {
                      // Not used in this app
                    },
                  );
                },
              ),
            )
          // Show details form for both camera photos and uploaded images
          else if (_isPhotoTaken)
            Positioned.fill(
              child: _buildDetailsForm(),
            ),

          // Aurora conditions overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildConditionItem('BzH', '${_currentBzH.toStringAsFixed(1)} nT'),
                      _buildConditionItem('Kp', _currentKp.toStringAsFixed(1)),
                      _buildConditionItem('📍', _locationName),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      AuroraMessageService.getCombinedAuroraMessage(_currentKp, _currentBzH),
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Camera controls (only show for camera mode)
          if (_showCaptureUI && !_showDetailsForm && widget.initialImagePath == null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Close button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),

          // Aurora sighting details form
          if (_showDetailsForm)
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _slideController,
                curve: Curves.easeOut,
              )),
              child: _buildDetailsForm(),
            ),
        ],
      ),
    );
  }



  Widget _buildConditionItem(String label, String value) {
    Color valueColor = Colors.white;
    if (label == 'BzH') {
      // Color coding for BzH values
      double bzValue = double.tryParse(value.replaceAll(' nT', '')) ?? 0;
      if (bzValue < -10) {
        valueColor = Colors.red; // Strong negative BzH (good for aurora)
      } else if (bzValue < -5) {
        valueColor = Colors.orange; // Moderate negative BzH
      } else if (bzValue < 0) {
        valueColor = Colors.yellow; // Slight negative BzH
      }
    } else if (label == 'Kp') {
      // Color coding for Kp values
      double kpValue = double.tryParse(value) ?? 0;
      if (kpValue >= 5) {
        valueColor = Colors.red; // Strong geomagnetic activity
      } else if (kpValue >= 4) {
        valueColor = Colors.orange; // Moderate geomagnetic activity
      } else if (kpValue >= 3) {
        valueColor = Colors.yellow; // Minor geomagnetic activity
      }
    }

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
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: valueColor.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsForm() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Colors.tealAccent,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Share Your Aurora Sighting',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _retakePhoto,
                  child: Text(
                    widget.initialImagePath != null ? 'Change Photo' : 'Retake',
                    style: TextStyle(color: Colors.tealAccent),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo preview
                  if (_capturedPhoto != null)
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _capturedPhoto!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  SizedBox(height: 20),

                  // Intensity selector
                  DetailedIntensitySelector(
                    selectedIntensity: _selectedIntensity,
                    onIntensityChanged: (intensity) {
                      setState(() {
                        _selectedIntensity = intensity;
                      });
                    },
                  ),

                  SizedBox(height: 20),

                  // Description
                  Text(
                    'Description (Optional)',
                    style: TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(color: Colors.white),
                    maxLength: 200,
                    maxLines: 3,
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

                  SizedBox(height: 20),

                  // Location info
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.tealAccent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationName,
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Submit button
          Container(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAuroraSighting,
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
                      'Sharing Aurora...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
                    : Text(
                  '🌌 SHOUT AURORA SIGHTING!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}