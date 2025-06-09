// lib/screens/camera_aurora_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Native camera method channel
  static const MethodChannel _cameraChannel = MethodChannel('aurora_camera/native');

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
  bool _showManualControls = false;
  bool _nightVisionMode = false;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _manualControlsController;

  final TextEditingController _descriptionController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();

  // Camera variables
  bool _isPhotoTaken = false;
  String? _photoPath;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  // Manual camera control variables
  double _currentISO = 1600.0;
  double _currentExposureTime = 5.0; // In seconds for long exposure
  double _currentFocus = 1.0; // 0.0 = close, 1.0 = infinity
  int _timerSeconds = 0;
  bool _isTimerActive = false;
  Timer? _captureTimer;
  int _countdownValue = 0;

  // Camera capability ranges (will be set by native camera)
  double _minISO = 100.0;
  double _maxISO = 6400.0;
  double _minExposureTime = 0.1;
  double _maxExposureTime = 30.0;

  // Aurora presets (exposure time in seconds)
  final Map<String, Map<String, double>> _auroraPresets = {
    'Faint Aurora': {'iso': 3200.0, 'exposure': 10.0, 'focus': 1.0},
    'Moderate Aurora': {'iso': 1600.0, 'exposure': 5.0, 'focus': 1.0},
    'Bright Aurora': {'iso': 800.0, 'exposure': 3.0, 'focus': 1.0},
    'Star Focus': {'iso': 1600.0, 'exposure': 8.0, 'focus': 1.0},
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Lock orientation to portrait (vertical)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _manualControlsController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Check if an initial image was provided (from gallery upload)
    if (widget.initialImagePath != null) {
      _isPhotoTaken = true;
      _capturedPhoto = File(widget.initialImagePath!);
      _photoPath = widget.initialImagePath;
    } else {
      // Initialize native camera for new photos
      _initializeNativeCamera();
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
    // Restore orientation to allow all
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _pulseController.dispose();
    _slideController.dispose();
    _manualControlsController.dispose();
    _descriptionController.dispose();
    _auroraDataTimer?.cancel();
    _captureTimer?.cancel();
    _disposeNativeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _disposeNativeCamera();
    } else if (state == AppLifecycleState.resumed) {
      if (!_isPhotoTaken && widget.initialImagePath == null) {
        _initializeNativeCamera();
      }
    }
  }

  // Native camera methods
  Future<void> _initializeNativeCamera() async {
    try {
      print('🔧 Initializing native camera...');
      
      // Request camera permissions
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        _showPermissionDialog('Camera permission is required for aurora photography');
        return;
      }

      final result = await _cameraChannel.invokeMethod('initializeCamera');
      
      if (result['success'] == true) {
        setState(() {
          _isCameraInitialized = true;
          
          // Update camera capability ranges from native side
          _minISO = result['minISO']?.toDouble() ?? 100.0;
          _maxISO = result['maxISO']?.toDouble() ?? 6400.0;
          _minExposureTime = result['minExposureTime']?.toDouble() ?? 0.1;
          _maxExposureTime = result['maxExposureTime']?.toDouble() ?? 30.0;
        });
        
        print('✅ Native camera initialized successfully');
        print('   ISO range: ${_minISO.round()} - ${_maxISO.round()}');
        print('   Exposure range: ${_minExposureTime}s - ${_maxExposureTime}s');
        
        // Apply initial settings
        _applyCameraSettings();
      } else {
        throw Exception(result['error'] ?? 'Failed to initialize camera');
      }
      
    } catch (e) {
      print('❌ Failed to initialize native camera: $e');
      _showErrorDialog('Failed to initialize professional camera controls: $e');
    }
  }

  Future<void> _disposeNativeCamera() async {
    try {
      if (_isCameraInitialized) {
        await _cameraChannel.invokeMethod('disposeCamera');
        setState(() {
          _isCameraInitialized = false;
        });
        print('🔧 Native camera disposed');
      }
    } catch (e) {
      print('⚠️ Error disposing camera: $e');
    }
  }

  Future<void> _applyCameraSettings() async {
    if (!_isCameraInitialized) return;
    
    try {
      print('📸 Applying camera settings to native camera:');
      print('   ISO: ${_currentISO.round()}');
      print('   Exposure Time: ${_currentExposureTime}s');
      print('   Focus: ${_currentFocus == 1.0 ? 'Infinity' : '${(_currentFocus * 100).round()}%'}');

      final result = await _cameraChannel.invokeMethod('applyCameraSettings', {
        'iso': _currentISO.round(),
        'exposureTimeSeconds': _currentExposureTime,
        'focusDistance': _currentFocus,
      });

      if (result['success'] == true) {
        HapticFeedback.selectionClick();
        print('✅ Camera settings applied successfully');
      } else {
        print('⚠️ Failed to apply some camera settings: ${result['error']}');
      }
      
    } catch (e) {
      print('❌ Error applying camera settings: $e');
    }
  }

  Future<void> _capturePhotoWithNativeCamera() async {
    if (!_isCameraInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      print('📸 Starting native camera capture...');
      print('   Settings: ISO ${_currentISO.round()}, ${_currentExposureTime}s exposure');

      // Show capture feedback
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📸 Capturing ${_currentExposureTime}s exposure... Please hold still!'),
          backgroundColor: _primaryColor,
          duration: Duration(seconds: (_currentExposureTime + 2).round()),
        ),
      );

      final result = await _cameraChannel.invokeMethod('capturePhoto');

      if (result['success'] == true) {
        final imagePath = result['imagePath'] as String;
        
        setState(() {
          _isPhotoTaken = true;
          _photoPath = imagePath;
          _capturedPhoto = File(imagePath);
          _isCapturing = false;
        });

        print('✅ Photo captured successfully: $imagePath');
        
        // Hide snackbar and show success
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Aurora photo captured successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

      } else {
        throw Exception(result['error'] ?? 'Failed to capture photo');
      }

    } catch (e) {
      setState(() {
        _isCapturing = false;
      });
      
      print('❌ Failed to capture photo: $e');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showErrorDialog('Failed to capture photo: $e');
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
    
    // Reinitialize camera
    _initializeNativeCamera();
  }

  void _toggleManualControls() {
    setState(() {
      _showManualControls = !_showManualControls;
    });
    if (_showManualControls) {
      _manualControlsController.forward();
    } else {
      _manualControlsController.reverse();
    }
  }

  void _toggleNightVision() {
    setState(() {
      _nightVisionMode = !_nightVisionMode;
    });
    HapticFeedback.lightImpact();
  }

  void _applyAuroraPreset(String presetName) {
    final preset = _auroraPresets[presetName];
    if (preset != null) {
      setState(() {
        _currentISO = preset['iso']!.clamp(_minISO, _maxISO);
        _currentExposureTime = preset['exposure']!.clamp(_minExposureTime, _maxExposureTime);
        _currentFocus = preset['focus']!;
      });
      
      // Apply settings to camera
      _applyCameraSettings();
      
      HapticFeedback.mediumImpact();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied $presetName preset - ISO: ${_currentISO.round()}, Exposure: ${_currentExposureTime}s'),
          backgroundColor: _primaryColor.withOpacity(0.9),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startCaptureTimer() {
    if (_timerSeconds == 0) {
      // Capture immediately
      _capturePhotoWithNativeCamera();
      return;
    }

    setState(() {
      _isTimerActive = true;
      _countdownValue = _timerSeconds;
    });

    HapticFeedback.heavyImpact();

    _captureTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _countdownValue--;
      });

      // Haptic feedback for countdown
      if (_countdownValue > 0) {
        HapticFeedback.lightImpact();
      }

      if (_countdownValue <= 0) {
        timer.cancel();
        setState(() {
          _isTimerActive = false;
        });
        _capturePhotoWithNativeCamera();
      }
    });
  }

  void _cancelTimer() {
    if (_captureTimer != null) {
      _captureTimer!.cancel();
      setState(() {
        _isTimerActive = false;
        _countdownValue = 0;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _nightVisionMode ? Colors.red.shade900 : Colors.black,
        title: Text('Permission Required', 
          style: TextStyle(color: _nightVisionMode ? Colors.red.shade100 : Colors.tealAccent)),
        content: Text(message, 
          style: TextStyle(color: _nightVisionMode ? Colors.red.shade200 : Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', 
              style: TextStyle(color: _nightVisionMode ? Colors.red.shade300 : Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Settings', 
              style: TextStyle(color: _nightVisionMode ? Colors.red.shade100 : Colors.tealAccent)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _nightVisionMode ? Colors.red.shade900 : Colors.black,
        title: Text('Error', 
          style: TextStyle(color: Colors.red)),
        content: Text(message, 
          style: TextStyle(color: _nightVisionMode ? Colors.red.shade200 : Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', 
              style: TextStyle(color: _nightVisionMode ? Colors.red.shade100 : Colors.tealAccent)),
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
        backgroundColor: _nightVisionMode ? Colors.red.shade900 : Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, 
              color: _nightVisionMode ? Colors.red.shade100 : Colors.tealAccent, size: 28),
            SizedBox(width: 12),
            Text(
              'Aurora Shared!',
              style: TextStyle(
                color: _nightVisionMode ? Colors.red.shade100 : Colors.tealAccent, 
                fontSize: 18
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🌌 Your professional aurora photo has been shared with the community!',
              style: TextStyle(color: _nightVisionMode ? Colors.red.shade200 : Colors.white70),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_nightVisionMode ? Colors.red.shade100 : Colors.tealAccent).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (_nightVisionMode ? Colors.red.shade100 : Colors.tealAccent).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.print, 
                    color: _nightVisionMode ? Colors.red.shade100 : Colors.tealAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your high-quality aurora photo is now available in the Print Shop!',
                      style: TextStyle(
                        color: _nightVisionMode ? Colors.red.shade100 : Colors.tealAccent,
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
              style: TextStyle(
                color: _nightVisionMode ? Colors.red.shade100 : Colors.tealAccent, 
                fontWeight: FontWeight.bold
              ),
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

  Color get _primaryColor => _nightVisionMode ? Colors.red.shade100 : Colors.tealAccent;
  Color get _backgroundColor => _nightVisionMode ? Colors.red.shade900.withOpacity(0.9) : Colors.black;
  Color get _textColor => _nightVisionMode ? Colors.red.shade100 : Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _nightVisionMode ? Colors.red.shade900 : Colors.black,
      body: Stack(
        children: [
          // Native camera preview
          if (!_isPhotoTaken && widget.initialImagePath == null)
            Positioned.fill(
              child: _isCameraInitialized 
                ? AndroidView(
                    viewType: 'aurora_camera_preview',
                    onPlatformViewCreated: (id) {
                      print('🔧 Camera preview created with ID: $id');
                    },
                  )
                : Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: _primaryColor),
                          SizedBox(height: 20),
                          Text(
                            'Initializing Professional Camera...',
                            style: TextStyle(color: _textColor, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
            )
          // Show details form for both camera photos and uploaded images
          else if (_isPhotoTaken)
            Positioned.fill(
              child: _buildDetailsForm(),
            ),

          // Top-left controls (Close button)
          if (!_isPhotoTaken && widget.initialImagePath == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: _backgroundColor.withOpacity(0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: _primaryColor.withOpacity(0.3)),
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: _textColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

          // Top-right controls (Night vision and manual controls)
          if (!_isPhotoTaken && widget.initialImagePath == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              right: 20,
              child: Column(
                children: [
                  // Night vision toggle
                  Container(
                    decoration: BoxDecoration(
                      color: _backgroundColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: _primaryColor.withOpacity(0.3)),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _nightVisionMode ? Icons.visibility_off : Icons.visibility,
                        color: _primaryColor,
                      ),
                      onPressed: _toggleNightVision,
                    ),
                  ),
                  
                  SizedBox(height: 12),
                  
                  // Manual controls toggle
                  Container(
                    decoration: BoxDecoration(
                      color: _backgroundColor.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: _primaryColor.withOpacity(0.3)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.tune, color: _primaryColor),
                      onPressed: _toggleManualControls,
                    ),
                  ),
                ],
              ),
            ),

          // Current settings display and capture button
          if (!_isPhotoTaken && widget.initialImagePath == null && !_showManualControls)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 40,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  // Current settings display
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _backgroundColor.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          'ISO: ${_currentISO.round()}',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_currentExposureTime.toStringAsFixed(1)}s',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Focus: ${_currentFocus == 1.0 ? '∞' : '${(_currentFocus * 100).round()}%'}',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Professional capture button
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _primaryColor,
                          _primaryColor.withOpacity(0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(40),
                        onTap: _isCapturing ? null : _startCaptureTimer,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: _isCapturing
                              ? Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Icon(
                                  _timerSeconds > 0 ? Icons.timer : Icons.camera_alt,
                                  color: Colors.white,
                                  size: 35,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Manual controls panel
          if (_showManualControls && !_isPhotoTaken)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: _manualControlsController,
                  curve: Curves.easeOut,
                )),
                child: _buildManualControlsPanel(),
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

          // Timer countdown overlay
          if (_isTimerActive)
            Positioned.fill(
              child: Container(
                color: (_nightVisionMode ? Colors.red.shade900 : Colors.black).withOpacity(0.9),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _primaryColor,
                            width: 4,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$_countdownValue',
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                      Text(
                        'Get ready for ${_currentExposureTime}s professional exposure...',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'ISO: ${_currentISO.round()} • Focus: ${_currentFocus == 1.0 ? '∞' : '${(_currentFocus * 100).round()}%'}',
                        style: TextStyle(
                          color: _textColor.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 30),
                      TextButton(
                        onPressed: _cancelTimer,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: _textColor.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: _textColor.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildManualControlsPanel() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _textColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.camera_alt, color: _primaryColor, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Professional Aurora Photography',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _toggleManualControls,
                  icon: Icon(Icons.close, color: _textColor),
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
                  // Camera status
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isCameraInitialized 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isCameraInitialized 
                            ? Colors.green.withOpacity(0.3)
                            : Colors.orange.withOpacity(0.3)
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isCameraInitialized ? Icons.check_circle : Icons.warning,
                          color: _isCameraInitialized ? Colors.green : Colors.orange,
                          size: 20
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isCameraInitialized 
                                ? 'Professional Camera Ready - Full Manual Control'
                                : 'Initializing Camera2 API...',
                            style: TextStyle(
                              color: _isCameraInitialized ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Aurora Presets
                  Text(
                    'Aurora Presets',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _auroraPresets.keys.map((presetName) {
                      return InkWell(
                        onTap: () => _applyAuroraPreset(presetName),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _primaryColor.withOpacity(0.3)),
                          ),
                          child: Text(
                            presetName,
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 24),

                  // Manual Controls
                  _buildSliderControl(
                    'ISO',
                    _currentISO,
                    _minISO,
                    _maxISO,
                    (value) {
                      setState(() => _currentISO = value);
                      _applyCameraSettings();
                    },
                    '${_currentISO.round()}',
                  ),

                  SizedBox(height: 20),

                  _buildSliderControl(
                    'Exposure Time',
                    _currentExposureTime,
                    _minExposureTime,
                    _maxExposureTime,
                    (value) {
                      setState(() => _currentExposureTime = value);
                      _applyCameraSettings();
                    },
                    '${_currentExposureTime.toStringAsFixed(1)}s',
                  ),

                  SizedBox(height: 20),

                  _buildSliderControl(
                    'Focus',
                    _currentFocus,
                    0.0,
                    1.0,
                    (value) {
                      setState(() => _currentFocus = value);
                      _applyCameraSettings();
                    },
                    _currentFocus == 1.0 ? '∞' : '${(_currentFocus * 100).round()}%',
                  ),

                  SizedBox(height: 24),

                  // Timer
                  Text(
                    'Self Timer',
                    style: TextStyle(
                      color: _primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [0, 3, 5, 10].map((seconds) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () => setState(() => _timerSeconds = seconds),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _timerSeconds == seconds
                                    ? _primaryColor.withOpacity(0.2)
                                    : _primaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _timerSeconds == seconds
                                      ? _primaryColor
                                      : _primaryColor.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                seconds == 0 ? 'Off' : '${seconds}s',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _timerSeconds == seconds
                                      ? _primaryColor
                                      : _textColor.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  SizedBox(height: 32),

                  // Professional capture button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isCameraInitialized && !_isCapturing) ? _startCaptureTimer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: _nightVisionMode ? Colors.red.shade900 : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 8,
                      ),
                      child: _isCapturing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _nightVisionMode ? Colors.red.shade900 : Colors.black,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Capturing ${_currentExposureTime}s...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _timerSeconds == 0 
                                ? '📸 PROFESSIONAL CAPTURE (${_currentExposureTime}s)' 
                                : '📸 START TIMER (${_timerSeconds}s)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderControl(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
    String displayValue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: _primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _primaryColor,
            inactiveTrackColor: _primaryColor.withOpacity(0.3),
            thumbColor: _primaryColor,
            overlayColor: _primaryColor.withOpacity(0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildConditionItem(String label, String value) {
    Color valueColor = _textColor;
    if (label == 'BzH') {
      // Color coding for BzH values
      double bzValue = double.tryParse(value.replaceAll(' nT', '')) ?? 0;
      if (bzValue < -10) {
        valueColor = _nightVisionMode ? Colors.red.shade200 : Colors.red;
      } else if (bzValue < -5) {
        valueColor = _nightVisionMode ? Colors.red.shade300 : Colors.orange;
      } else if (bzValue < 0) {
        valueColor = _nightVisionMode ? Colors.red.shade400 : Colors.yellow;
      }
    } else if (label == 'Kp') {
      // Color coding for Kp values
      double kpValue = double.tryParse(value) ?? 0;
      if (kpValue >= 5) {
        valueColor = _nightVisionMode ? Colors.red.shade200 : Colors.red;
      } else if (kpValue >= 4) {
        valueColor = _nightVisionMode ? Colors.red.shade300 : Colors.orange;
      } else if (kpValue >= 3) {
        valueColor = _nightVisionMode ? Colors.red.shade400 : Colors.yellow;
      }
    } else if (label == '📍') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Tooltip(
            message: value,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 160),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _backgroundColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: valueColor.withOpacity(0.3)),
              ),
              child: Text(
                value.length > 24 ? value.substring(0, 24) + '...' : value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _backgroundColor.withOpacity(0.5),
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
        color: _backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _textColor.withOpacity(0.5),
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
                  color: _primaryColor,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Post sighting',
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _retakePhoto,
                  child: Text(
                    widget.initialImagePath != null ? 'Change Photo' : 'Retake',
                    style: TextStyle(color: _primaryColor),
                  ),
                ),
              ],
            ),
          ),

          // --- Moved conditions card here ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _backgroundColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
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
                      color: _backgroundColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _primaryColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      AuroraMessageService.getCombinedAuroraMessage(_currentKp, _currentBzH),
                      style: TextStyle(
                        color: _textColor.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // --- End moved conditions card ---

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
                        border: Border.all(color: _primaryColor.withOpacity(0.3)),
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
                      color: _primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(color: _textColor),
                    maxLength: 200,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe what you see...',
                      hintStyle: TextStyle(color: _textColor.withOpacity(0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryColor.withOpacity(0.5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryColor.withOpacity(0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _primaryColor),
                      ),
                      counterStyle: TextStyle(color: _textColor.withOpacity(0.5)),
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
                      color: _textColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _textColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, color: _primaryColor, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _locationName,
                            style: TextStyle(color: _textColor.withOpacity(0.8), fontSize: 14),
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
                  backgroundColor: _primaryColor,
                  foregroundColor: _nightVisionMode ? Colors.red.shade900 : Colors.black,
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
                        color: _nightVisionMode ? Colors.red.shade900 : Colors.black,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Posting sighting...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
                    : Text(
                  'Post sighting',
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