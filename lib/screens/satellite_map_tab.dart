import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/cloud_cover_service.dart';
import '../widgets/forecast/cloud_cover_map.dart';

class SatelliteMapTab extends StatefulWidget {
  const SatelliteMapTab({super.key});

  @override
  State<SatelliteMapTab> createState() => _SatelliteMapTabState();
}

class _SatelliteMapTabState extends State<SatelliteMapTab> {
  Position? _currentPosition;
  Map<String, dynamic>? _cloudCoverData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCloudCoverData();
  }

  Future<void> _loadCloudCoverData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final position = await CloudCoverService.getCurrentLocation();
      final data = await CloudCoverService.getCloudCoverData(position);
      setState(() {
        _currentPosition = position;
        _cloudCoverData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load cloud cover data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Satellite Map', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _currentPosition == null || _cloudCoverData == null
                  ? const Center(child: Text('No data available', style: TextStyle(color: Colors.white70)))
                  : CloudCoverMap(
                      position: _currentPosition!,
                      cloudCover: (_cloudCoverData!["cloudCover"] as num).toDouble(),
                      weatherDescription: _cloudCoverData!["weatherDescription"] ?? "No description available",
                      weatherIcon: _cloudCoverData!["weatherIcon"] ?? "01d",
                    ),
    );
  }
} 