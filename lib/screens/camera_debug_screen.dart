// This file is excluded from production builds. Recommend removing from build or export list.

// lib/screens/camera_debug_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraDebugScreen extends StatefulWidget {
  @override
  _CameraDebugScreenState createState() => _CameraDebugScreenState();
}

class _CameraDebugScreenState extends State<CameraDebugScreen> {
  static const MethodChannel _cameraChannel = MethodChannel('aurora_camera/native');
  
  Map<String, dynamic>? _cameraInfo;
  String _debugLog = '';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _debugCamera();
  }

  Future<void> _debugCamera() async {
    setState(() {
      _debugLog = 'Starting camera debug...\n';
    });

    try {
      // Initialize camera and get detailed info
      final result = await _cameraChannel.invokeMethod('initializeCamera');
      
      setState(() {
        _cameraInfo = result;
        _isInitialized = result['success'] == true;
        _debugLog += 'Camera initialization result:\n';
        _debugLog += 'Success: ${result['success']}\n';
        
        if (result['success'] == true) {
          _debugLog += 'Min ISO: ${result['minISO']}\n';
          _debugLog += 'Max ISO: ${result['maxISO']}\n';
          _debugLog += 'Min Exposure: ${result['minExposureTime']} seconds\n';
          _debugLog += 'Max Exposure: ${result['maxExposureTime']} seconds\n';
        } else {
          _debugLog += 'Error: ${result['error']}\n';
        }
      });

    } catch (e) {
      setState(() {
        _debugLog += 'Exception during initialization: $e\n';
      });
    }
  }

  Future<void> _testCameraSettings() async {
    if (!_isInitialized) return;

    setState(() {
      _debugLog += '\nTesting camera settings...\n';
    });

    try {
      // Test with conservative settings first
      final result = await _cameraChannel.invokeMethod('applyCameraSettings', {
        'iso': 800,
        'exposureTimeSeconds': 0.1, // Start with 0.1 second
        'focusDistance': 1.0,
      });

      setState(() {
        _debugLog += 'Settings test result:\n';
        _debugLog += 'Success: ${result['success']}\n';
        if (result['success'] == true) {
          _debugLog += 'Applied ISO: ${result['appliedISO']}\n';
          _debugLog += 'Applied Exposure: ${result['appliedExposureTime']}s\n';
          _debugLog += 'Applied Focus: ${result['appliedFocusDistance']}\n';
        } else {
          _debugLog += 'Settings Error: ${result['error']}\n';
        }
      });

    } catch (e) {
      setState(() {
        _debugLog += 'Settings Exception: $e\n';
      });
    }
  }

  Future<void> _testCapture() async {
    if (!_isInitialized) return;

    setState(() {
      _debugLog += '\nTesting photo capture...\n';
    });

    try {
      final result = await _cameraChannel.invokeMethod('capturePhoto');

      setState(() {
        _debugLog += 'Capture result:\n';
        _debugLog += 'Success: ${result['success']}\n';
        if (result['success'] == true) {
          _debugLog += 'Image saved to: ${result['imagePath']}\n';
        } else {
          _debugLog += 'Capture Error: ${result['error']}\n';
        }
      });

    } catch (e) {
      setState(() {
        _debugLog += 'Capture Exception: $e\n';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Camera Debug', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Camera Status
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isInitialized ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isInitialized ? Colors.green : Colors.red,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Camera Status: ${_isInitialized ? 'INITIALIZED' : 'FAILED'}',
                    style: TextStyle(
                      color: _isInitialized ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_cameraInfo != null) ...[
                    SizedBox(height: 8),
                    Text(
                      'Device Camera Capabilities:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ISO Range: ${_cameraInfo!['minISO']} - ${_cameraInfo!['maxISO']}',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'Exposure Range: ${_cameraInfo!['minExposureTime']}s - ${_cameraInfo!['maxExposureTime']}s',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 20),

            // Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testCameraSettings,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: Text('Test Settings'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testCapture,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: Text('Test Capture'),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Debug Log
            Text(
              'Debug Log:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: Text(
                _debugLog,
                style: TextStyle(
                  color: Colors.green.shade300,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),

            SizedBox(height: 20),

            // Camera Preview Test
            Text(
              'Camera Preview Test:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isInitialized
                  ? AndroidView(
                      viewType: 'aurora_camera_preview',
                      onPlatformViewCreated: (id) {
                        setState(() {
                          _debugLog += 'Platform view created with ID: $id\n';
                        });
                      },
                    )
                  : Center(
                      child: Text(
                        'Camera not initialized',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}