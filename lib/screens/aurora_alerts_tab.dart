// lib/screens/aurora_alerts_tab.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/aurora_sighting.dart';
import '../services/aurora_community_service.dart';
import '../widgets/sighting_card.dart';
import '../widgets/aurora_map.dart';

class AuroraAlertsTab extends StatefulWidget {
  const AuroraAlertsTab({super.key});

  @override
  State<AuroraAlertsTab> createState() => _AuroraAlertsTabState();
}

class _AuroraAlertsTabState extends State<AuroraAlertsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Position? _currentLocation;
  List<AuroraSighting> _recentSightings = [];
  List<AuroraSighting> _nearbySightings = [];
  bool _isLoading = true;
  String _activityLevel = 'Loading...';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _getCurrentLocation();
    _loadSightings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.denied) {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentLocation = position;
        });
        _loadNearbySightings();
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  void _loadSightings() {
    AuroraCommunityService.getRecentSightings().listen((sightings) {
      if (mounted) {
        setState(() {
          _recentSightings = sightings;
          _activityLevel = AuroraCommunityService.getActivityLevel(sightings);
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadNearbySightings() async {
    if (_currentLocation == null) return;

    try {
      final nearbySightings = await AuroraCommunityService.getSightingsNearLocation(
        center: GeoPoint(_currentLocation!.latitude, _currentLocation!.longitude),
        radiusKm: 100, // 100km radius
      );

      if (mounted) {
        setState(() {
          _nearbySightings = nearbySightings;
        });
      }
    } catch (e) {
      print('Error loading nearby sightings: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    _loadSightings();
    if (_currentLocation != null) {
      await _loadNearbySightings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildActivityBanner(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMapView(),
                  _buildSightingsList(_recentSightings),
                  _buildSightingsList(_nearbySightings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Aurora Community',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.tealAccent,
              shadows: [Shadow(color: Colors.tealAccent, blurRadius: 8)],
            ),
          ),
          Spacer(),
          IconButton(
            onPressed: _refreshData,
            icon: _isLoading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.tealAccent,
              ),
            )
                : Icon(Icons.refresh, color: Colors.tealAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBanner() {
    final activityColor = _getActivityColor(_activityLevel);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            activityColor.withOpacity(0.2),
            activityColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activityColor.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activityColor,
              boxShadow: [
                BoxShadow(
                  color: activityColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Activity: $_activityLevel',
                  style: TextStyle(
                    color: activityColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_recentSightings.length} sightings in last 24h',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.trending_up,
            color: activityColor,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.tealAccent,
          borderRadius: BorderRadius.circular(25),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white70,
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: [
          Tab(
            icon: Icon(Icons.map, size: 16),
            text: 'Map',
          ),
          Tab(
            icon: Icon(Icons.access_time, size: 16),
            text: 'Recent',
          ),
          Tab(
            icon: Icon(Icons.location_on, size: 16),
            text: 'Nearby',
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    if (_currentLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.tealAccent),
            SizedBox(height: 16),
            Text(
              'Getting your location...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return AuroraMap(
      currentLocation: _currentLocation!,
      sightings: _recentSightings,
      onSightingTapped: _showSightingDetails,
    );
  }

  Widget _buildSightingsList(List<AuroraSighting> sightings) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Colors.tealAccent),
      );
    }

    if (sightings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white30,
            ),
            SizedBox(height: 16),
            Text(
              'No aurora sightings yet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to spot aurora in your area!',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: Colors.tealAccent,
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: sightings.length,
        itemBuilder: (context, index) {
          return SightingCard(
            sighting: sightings[index],
            currentLocation: _currentLocation,
            onTap: () => _showSightingDetails(sightings[index]),
            onConfirm: () => _confirmSighting(sightings[index]),
          );
        },
      ),
    );
  }

  void _showSightingDetails(AuroraSighting sighting) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildSightingDetailSheet(sighting),
    );
  }

  Widget _buildSightingDetailSheet(AuroraSighting sighting) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
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
                  color: _getIntensityColor(sighting.intensity),
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sighting.intensityDescription} Aurora',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'by ${sighting.userName} • ${sighting.timeAgo}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (sighting.isVerified)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.tealAccent, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                  // Location info
                  _buildDetailRow(
                    'Location',
                    '${sighting.locationName}\n${sighting.formattedCoordinates}',
                    Icons.location_on,
                  ),

                  // Weather conditions
                  if (sighting.weather.isNotEmpty)
                    _buildDetailRow(
                      'Conditions',
                      'BzH: ${sighting.weather['bzH']?.toStringAsFixed(1) ?? 'N/A'} nT\nKp: ${sighting.weather['kp']?.toStringAsFixed(1) ?? 'N/A'}',
                      Icons.thermostat,
                    ),

                  // Description
                  if (sighting.description != null)
                    _buildDetailRow(
                      'Description',
                      sighting.description!,
                      Icons.description,
                    ),

                  // Photos
                  if (sighting.photoUrls.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Photos',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: sighting.photoUrls.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 120,
                            margin: EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                sighting.photoUrls[index],
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.tealAccent,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.withOpacity(0.2),
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.white54,
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmSighting(sighting),
                    icon: Icon(Icons.thumb_up_outlined, size: 16),
                    label: Text('Confirm (${sighting.confirmations})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Navigate to spot aurora with same location
                    },
                    icon: Icon(Icons.add_a_photo, size: 16),
                    label: Text('Spot Here Too'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.tealAccent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSighting(AuroraSighting sighting) async {
    try {
      await AuroraCommunityService.confirmSighting(sighting.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thanks for confirming the sighting!'),
            backgroundColor: Colors.tealAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color _getActivityColor(String activityLevel) {
    switch (activityLevel.toLowerCase()) {
      case 'exceptional activity':
        return Colors.amber;
      case 'high activity':
        return Colors.orange;
      case 'moderate activity':
        return Colors.tealAccent;
      case 'low activity':
      case 'minimal activity':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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