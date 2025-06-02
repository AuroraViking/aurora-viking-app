// lib/screens/aurora_alerts_tab.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/aurora_sighting.dart';
import '../services/firebase_service.dart';
import '../widgets/aurora_post_card.dart';
import '../widgets/aurora_map.dart';
import '../widgets/sign_in_widget.dart';
import '../screens/spot_aurora_screen.dart';
import '../screens/edit_profile_screen.dart';

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
    _tabController = TabController(length: 4, vsync: this);
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

  Future<void> _loadSightings() async {
    setState(() => _isLoading = true);
    try {
      final recentSightings = await _firebaseService.getRecentSightings();
      final nearbySightings = await _firebaseService.getNearbySightings();
      setState(() {
        _recentSightings = recentSightings;
        _nearbySightings = nearbySightings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sightings: $e');
      setState(() => _isLoading = false);
    }
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
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aurora Sightings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'World'),
              Tab(text: 'Nearby'),
              Tab(text: 'Map'),
              Tab(text: 'My Profile'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_a_photo),
              onPressed: _navigateToSpotAurora,
            ),
          ],
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildSightingsList(_recentSightings),
            _buildSightingsList(_nearbySightings),
            _buildMapView(),
            _buildProfileView(),
          ],
        ),
      ),
    );
  }

  Widget _buildSightingsList(List<AuroraSighting> sightings) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sightings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.visibility_off, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'No aurora sightings yet',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _navigateToSpotAurora,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Spot Aurora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadSightings();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sightings.length,
        itemBuilder: (context, index) {
          final sighting = sightings[index];
          return AuroraPostCard(
            sighting: sighting,
            onLike: (sightingId) async {
              final result = await _firebaseService.confirmAuroraSighting(sightingId);
              setState(() {
                // Update both lists to ensure consistency
                _updateSightingInList(_recentSightings, sightingId, result);
                _updateSightingInList(_nearbySightings, sightingId, result);
              });
            },
            onShare: (sightingId) {
              // TODO: Implement share functionality
            },
            onViewProfile: (userId) {
              // TODO: Navigate to user profile
              print('View profile for user: $userId');
            },
            onViewLocation: (location) {
              // TODO: Show location on map
              print('Show location: ${location.latitude}, ${location.longitude}');
            },
          );
        },
      ),
    );
  }

  Widget _buildMapView() {
    if (_isLoadingLocation) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentLocation == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Location access required',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.location_searching),
              label: const Text('Enable Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    return AuroraMap(
      currentLocation: _currentLocation!,
      sightings: [..._recentSightings, ..._nearbySightings],
      onSightingTapped: (sighting) {
        // Show a bottom sheet with sighting details
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.black.withOpacity(0.9),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getIntensityColor(sighting.intensity),
                          child: Text(
                            sighting.intensity.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${sighting.locationName} • ${sighting.timeAgo}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Photos
                    if (sighting.photoUrls.isNotEmpty)
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          itemCount: sighting.photoUrls.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              sighting.photoUrls[index],
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Description
                    if (sighting.description != null && sighting.description!.isNotEmpty)
                      Text(
                        sighting.description!,
                        style: const TextStyle(color: Colors.white),
                      ),

                    const SizedBox(height: 16),

                    // Weather conditions
                    if (sighting.weather.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.thermostat, color: Colors.tealAccent, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'BzH: ${sighting.weather['bzH']?.toStringAsFixed(1) ?? 'N/A'} nT • Kp: ${sighting.weather['kp']?.toStringAsFixed(1) ?? 'N/A'}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              await _firebaseService.confirmAuroraSighting(sighting.id);
                              _loadSightings();
                              if (mounted) Navigator.pop(context);
                            },
                            icon: Icon(
                              sighting.confirmedByUsers.contains(_firebaseService.currentUser?.uid)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: sighting.confirmedByUsers.contains(_firebaseService.currentUser?.uid)
                                  ? Colors.red
                                  : Colors.white70,
                            ),
                            label: Text(
                              '${sighting.confirmations}',
                              style: TextStyle(
                                color: sighting.confirmedByUsers.contains(_firebaseService.currentUser?.uid)
                                    ? Colors.red
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              // Handle comment action
                            },
                            icon: const Icon(Icons.comment_outlined, color: Colors.white70),
                            label: const Text(
                              'Comment',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              // Handle share action
                            },
                            icon: const Icon(Icons.share_outlined, color: Colors.white70),
                            label: const Text(
                              'Share',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileView() {
    final user = _firebaseService.currentUser;
    if (user == null) {
      return const Center(
        child: SignInWidget(),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: _firebaseService.firestore.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Profile not found'));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final profilePictureUrl = userData['profilePictureUrl'] as String?;
        final bannerUrl = userData['bannerUrl'] as String?;
        final bio = userData['bio'] as String? ?? 'No bio yet';
        final auroraSpottingCount = userData['auroraSpottingCount'] as int? ?? 0;
        final verificationCount = userData['verificationCount'] as int? ?? 0;

        return SingleChildScrollView(
          child: Column(
            children: [
              // Banner Image
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.tealAccent.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                  image: bannerUrl != null
                      ? DecorationImage(
                          image: NetworkImage(bannerUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              ),

              // Profile Picture and Name
              Transform.translate(
                offset: const Offset(0, -50),
                child: Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: profilePictureUrl != null
                            ? NetworkImage(profilePictureUrl)
                            : null,
                        child: profilePictureUrl == null
                            ? Text(
                                user.displayName?[0].toUpperCase() ?? 'U',
                                style: const TextStyle(fontSize: 32),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName ?? 'Anonymous',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stats
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn('Sightings', auroraSpottingCount),
                    _buildStatColumn('Verifications', verificationCount),
                  ],
                ),
              ),

              // Bio
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(bio),
                  ],
                ),
              ),

              // Edit Profile Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    ).then((_) => setState(() {})); // Refresh profile after editing
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),

              // User's Aurora Photos
              const Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'My Aurora Photos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _firebaseService.getUserPhotoStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No photos yet'),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final photo = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      return Image.network(
                        photo['photoUrl'] as String,
                        fit: BoxFit.cover,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
          ),
        ),
      ],
    );
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

  void _updateSightingInList(List<AuroraSighting> list, String sightingId, Map<String, dynamic> result) {
    final index = list.indexWhere((s) => s.id == sightingId);
    if (index != -1) {
      list[index] = list[index].copyWith(
        confirmations: result['confirmations'],
        confirmedByUsers: result['isLiked'] 
          ? [...list[index].confirmedByUsers, _firebaseService.currentUser!.uid]
          : list[index].confirmedByUsers.where((id) => id != _firebaseService.currentUser!.uid).toList(),
        isVerified: result['confirmations'] >= 3,
      );
    }
  }
}