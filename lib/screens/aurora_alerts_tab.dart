// lib/screens/aurora_alerts_tab.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/aurora_sighting.dart';
import '../services/firebase_service.dart';
import '../widgets/sighting_card.dart';
import '../widgets/aurora_map.dart';
import '../widgets/sign_in_widget.dart';
import '../screens/spot_aurora_screen.dart';

class AuroraAlertsTab extends StatefulWidget {
  const AuroraAlertsTab({super.key});

  @override
  State<AuroraAlertsTab> createState() => _AuroraAlertsTabState();
}

class _AuroraAlertsTabState extends State<AuroraAlertsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();
  Position? _currentLocation;
  List<AuroraSighting> _recentSightings = [];
  List<AuroraSighting> _nearbySightings = [];
  bool _isLoading = true;
  bool _isLoadingLocation = true;
  String _activityLevel = 'No Recent Activity';

  // Dark theme map style
  static const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1d2c4d"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8ec3b9"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1a3646"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b6878"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#64779e"
      }
    ]
  },
  {
    "featureType": "administrative.province",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#4b6878"
      }
    ]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#334e87"
      }
    ]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#023e58"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#283d6a"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#6f9ba5"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1d2c4d"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#023e58"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#3C7680"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#304a7d"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#98a5be"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1d2c4d"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2c6675"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#255763"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#b0d5ce"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#023e58"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#98a5be"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1d2c4d"
      }
    ]
  },
  {
    "featureType": "transit.line",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#283d6a"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#3a4762"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0e1626"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#4e6d70"
      }
    ]
  }
]
''';


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
      setState(() => _isLoadingLocation = true);

      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.denied) {
        final position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _currentLocation = position;
            _isLoadingLocation = false;
          });
          _loadNearbySightings();
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  void _loadSightings() {
    print('🔄 Loading aurora sightings...');

    _firebaseService.getAuroraSightingsStream(limit: 50).listen(
          (QuerySnapshot snapshot) {
        print('📊 Received ${snapshot.docs.length} sightings from Firebase');

        if (mounted) {
          final now = DateTime.now();
          final twelveHoursAgo = now.subtract(const Duration(hours: 12));

          final sightings = snapshot.docs
              .map((doc) => AuroraSighting.fromFirestore(doc))
              .where((sighting) => sighting.timestamp.isAfter(twelveHoursAgo))
              .toList();

          setState(() {
            _recentSightings = sightings;
            _activityLevel = _calculateActivityLevel(sightings);
            _isLoading = false;
          });

          print('✅ Loaded ${sightings.length} recent sightings');
        }
      },
      onError: (error) {
        print('❌ Error loading sightings: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _activityLevel = 'Error Loading Data';
          });
        }
      },
    );
  }

  String _calculateActivityLevel(List<AuroraSighting> sightings) {
    if (sightings.isEmpty) return 'No Recent Activity';

    final now = DateTime.now();
    final last12Hours = now.subtract(const Duration(hours: 12));

    final recentSightings = sightings.where((sighting) {
      return sighting.timestamp.isAfter(last12Hours);
    }).toList();

    final count = recentSightings.length;

    if (count >= 10) return 'Exceptional Activity';
    if (count >= 6) return 'High Activity';
    if (count >= 3) return 'Moderate Activity';
    if (count >= 1) return 'Low Activity';
    return 'Minimal Activity';
  }

  Future<void> _loadNearbySightings() async {
    if (_currentLocation == null) return;

    try {
      print('🗺️ Loading nearby sightings...');

      final now = DateTime.now();
      final twelveHoursAgo = now.subtract(const Duration(hours: 12));

      final nearbySightings = await _firebaseService.getNearbyAuroraSightings(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radiusKm: 100,
        hours: 12,
      );

      if (mounted) {
        final sightings = nearbySightings
            .map((doc) => AuroraSighting.fromFirestore(doc))
            .where((sighting) => sighting.timestamp.isAfter(twelveHoursAgo))
            .toList();

        setState(() {
          _nearbySightings = sightings;
        });

        print('✅ Loaded ${sightings.length} nearby sightings');
      }
    } catch (e) {
      print('❌ Error loading nearby sightings: $e');
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
    return StreamBuilder<User?>(
      stream: _firebaseService.auth.authStateChanges(),
      builder: (context, authSnapshot) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildActivityBanner(),

                if (!_firebaseService.isAuthenticated) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SignInWidget(
                        onSignedIn: () {
                          setState(() {});
                          _loadSightings();
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildMapView(),
                        _buildSightingsList(_recentSightings, 'recent'),
                        _buildSightingsList(_nearbySightings, 'nearby'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          floatingActionButton: _firebaseService.isAuthenticated
              ? FloatingActionButton.extended(
                  onPressed: _navigateToSpotAurora,
                  backgroundColor: Colors.tealAccent,
                  icon: const Icon(Icons.camera_alt, color: Colors.black),
                  label: const Text(
                    'Spot Aurora',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Aurora Community',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.tealAccent,
              shadows: [Shadow(color: Colors.tealAccent, blurRadius: 8)],
            ),
          ),
          const Spacer(),
          if (_isLoading && _recentSightings.isEmpty)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.tealAccent,
              ),
            )
          else
            IconButton(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh, color: Colors.tealAccent),
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
          const SizedBox(width: 12),
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
                  '${_recentSightings.length} sightings in last 12h',
                  style: const TextStyle(
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
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: const [
          Tab(icon: Icon(Icons.map, size: 16), text: 'Map'),
          Tab(icon: Icon(Icons.access_time, size: 16), text: 'Recent'),
          Tab(icon: Icon(Icons.location_on, size: 16), text: 'Nearby'),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    if (_isLoadingLocation) {
      return const Center(
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

    if (_currentLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Location access needed',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Enable Location'),
            ),
          ],
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
        zoom: 8.0,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: true,
      zoomGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: true,
      rotateGesturesEnabled: true,
      compassEnabled: true,
      mapToolbarEnabled: true,
      mapType: MapType.normal,
      markers: _buildMapMarkers(),
      style: _darkMapStyle, // Added dark theme
      onMapCreated: (GoogleMapController controller) {
        print('🗺️ Map created successfully');
      },
      onTap: (LatLng position) {
        print('Map tapped at: ${position.latitude}, ${position.longitude}');
      },
    );
  }

  Set<Marker> _buildMapMarkers() {
    final markers = <Marker>{};

    for (int i = 0; i < _recentSightings.length; i++) {
      final sighting = _recentSightings[i];
      markers.add(
        Marker(
          markerId: MarkerId('sighting_$i'),
          position: LatLng(
            sighting.location.latitude,
            sighting.location.longitude,
          ),
          infoWindow: InfoWindow(
            title: '${sighting.intensityDescription} Aurora',
            snippet: sighting.locationName,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(sighting.intensity),
          ),
          onTap: () => _showSightingDetails(sighting),
        ),
      );
    }

    return markers;
  }

  double _getMarkerHue(int intensity) {
    switch (intensity) {
      case 1: return BitmapDescriptor.hueBlue;
      case 2: return BitmapDescriptor.hueGreen;
      case 3: return BitmapDescriptor.hueCyan;
      case 4: return BitmapDescriptor.hueOrange;
      case 5: return BitmapDescriptor.hueRed;
      default: return BitmapDescriptor.hueViolet;
    }
  }

  Widget _buildSightingsList(List<AuroraSighting> sightings, String type) {
    if (_isLoading && sightings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.tealAccent),
            const SizedBox(height: 16),
            Text(
              'Loading $type sightings...',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (sightings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.white30),
            const SizedBox(height: 16),
            Text(
              type == 'recent' ? 'No recent aurora sightings' : 'No nearby aurora sightings',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to spot aurora in your area!',
              style: TextStyle(color: Colors.white54, fontSize: 14),
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
        padding: const EdgeInsets.all(16),
        itemCount: sightings.length,
        itemBuilder: (context, index) {
          final sighting = sightings[index];
          return Card(
            color: Colors.white.withOpacity(0.05),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getIntensityColor(sighting.intensity),
                child: Text(
                  sighting.intensity.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                '${sighting.intensityDescription} Aurora',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sighting.locationName,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  Text(
                    'by ${sighting.userName} • ${sighting.timeAgo}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
              onTap: () => _showSightingDetails(sighting),
            ),
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
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white54,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getIntensityColor(sighting.intensity),
                    ),
                    child: Center(
                      child: Text(
                        sighting.intensity.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sighting.intensityDescription} Aurora',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'by ${sighting.userName} • ${sighting.timeAgo}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (sighting.isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
                      ),
                      child: const Row(
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      'Location',
                      '${sighting.locationName}\n${sighting.formattedCoordinates}',
                      Icons.location_on,
                    ),

                    if (sighting.weather.isNotEmpty)
                      _buildDetailRow(
                        'Aurora Conditions',
                        'BzH: ${sighting.weather['bzH']?.toStringAsFixed(1) ?? 'N/A'} nT\nKp: ${sighting.weather['kp']?.toStringAsFixed(1) ?? 'N/A'}',
                        Icons.thermostat,
                      ),

                    if (sighting.description != null && sighting.description!.isNotEmpty)
                      _buildDetailRow(
                        'Description',
                        sighting.description!,
                        Icons.description,
                      ),

                    if (sighting.photoUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Icon(Icons.photo_library, color: Colors.tealAccent, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Aurora Photos',
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: sighting.photoUrls.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 200,
                              margin: const EdgeInsets.only(right: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    Image.network(
                                      sighting.photoUrls[index],
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          width: 200,
                                          height: 200,
                                          color: Colors.grey.withOpacity(0.2),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.tealAccent,
                                              strokeWidth: 2,
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        print('❌ Error loading image: $error');
                                        return Container(
                                          width: 200,
                                          height: 200,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.broken_image,
                                                color: Colors.white54,
                                                size: 40,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Failed to load image',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 12,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _showFullScreenImage(sighting.photoUrls[index]),
                                          child: Container(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmSighting(sighting),
                      icon: const Icon(Icons.thumb_up_outlined, size: 16),
                      label: Text('Confirm (${sighting.confirmations})'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.tealAccent,
                        side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openCameraAtLocation(sighting.location);
                      },
                      icon: const Icon(Icons.add_a_photo, size: 16),
                      label: const Text('Spot Here Too'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.tealAccent,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white54, size: 64),
                        SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.tealAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
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

  void _openCameraAtLocation(GeoPoint location) {
    print('Opening camera at location: ${location.latitude}, ${location.longitude}');
  }

  Future<void> _confirmSighting(AuroraSighting sighting) async {
    try {
      await _firebaseService.verifyAuroraSighting(sighting.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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

  void _navigateToSpotAurora() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SpotAuroraScreen(
          currentBzH: 0.0, // You should get this from your aurora data service
          currentKp: 0.0,  // You should get this from your aurora data service
        ),
      ),
    );
  }
}