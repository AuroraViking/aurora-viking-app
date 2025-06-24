// lib/screens/aurora_alerts_tab.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/aurora_sighting.dart';
import '../models/user_aurora_photo.dart';
import '../widgets/aurora_post_card.dart';
import '../widgets/aurora_map.dart';
import '../widgets/sign_in_widget.dart';
import 'spot_aurora_screen.dart';
import 'edit_profile_screen.dart';
import 'user_profile_screen.dart';
import '../widgets/aurora_photo_viewer.dart';
import '../services/solar_wind_service.dart';
import '../services/kp_service.dart';
import '../widgets/admob_banner_card.dart';
import '../widgets/aurora_native_ad_card.dart';

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
  final String _activityLevel = 'No Recent Activity';
  GoogleMapController? _mapController;
  List<String> _notifiedSightingIds = []; // Track notified sighting IDs

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _getCurrentLocation();
    _loadSightings();
    initializeLocalNotifications();
    _checkHighActivityAlert();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
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
      // print('Error getting location: $e');
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
      if (mounted) {
        setState(() {
          _recentSightings = recentSightings;
          _nearbySightings = nearbySightings;
          _isLoading = false;
        });
      }
    } catch (e) {
      // print('Error loading sightings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNearbySightings() async {
    if (_currentLocation == null) return;
    try {
      final now = DateTime.now();
      final twelveHoursAgo = now.subtract(const Duration(hours: 12));
      final nearbySightings = await _firebaseService.getNearbyAuroraSightings(
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        radiusKm: 50, // 50 km radius for notifications
        hours: 12,
      );
      if (mounted) {
        final sightings = nearbySightings
            .map((doc) => AuroraSighting.fromFirestore(doc))
            .where((sighting) => sighting.timestamp.isAfter(twelveHoursAgo))
            .toList();
        // Notification logic: notify for new sightings in 50km radius
        if (await _firebaseService.shouldShowNearbyAlert()) {
          for (final sighting in sightings) {
            if (!_notifiedSightingIds.contains(sighting.id)) {
              showAuroraNearbyNotification(
                'Aurora Spotted Nearby!',
                '${sighting.userName} spotted the aurora near ${sighting.locationName}',
              );
              _notifiedSightingIds.add(sighting.id);
            }
          }
        }
        setState(() {
          _nearbySightings = sightings;
        });
      }
    } catch (e) {
      // print('Error loading nearby sightings: $e');
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadSightings(),
      if (_currentLocation != null) _loadNearbySightings(),
    ]);
  }

  Future<void> _checkHighActivityAlert() async {
    if (_currentLocation == null) return;
    if (!await _firebaseService.shouldShowHighActivityAlert()) return;
    // Fetch real-time BzH (mean of last 30 min Bz values)
    final bzHistory = await SolarWindService.fetchBzHistory();
    double bzH = 0.0;
    if (bzHistory.bzValues.isNotEmpty) {
      // Take the mean of the last 6 values (assuming 5-min intervals)
      final recent = bzHistory.bzValues.length >= 6
          ? bzHistory.bzValues.sublist(bzHistory.bzValues.length - 6)
          : bzHistory.bzValues;
      bzH = recent.reduce((a, b) => a + b) / recent.length;
    }
    // Fetch real-time Kp
    double kp = await KpService.fetchCurrentKp();
    double latitude = _currentLocation!.latitude;
    DateTime now = DateTime.now();
    bool isDark = now.hour < 4 || now.hour > 22; // Example: night hours
    double kpThreshold = latitude.abs() > 65 ? 2.0 : latitude.abs() > 55 ? 4.0 : 6.0;
    if (bzH >= 7.0 && kp >= kpThreshold && isDark) {
      showHighActivityNotification(
        'High Aurora Activity!',
        'Aurora is likely to form in your area within the hour. Look up!'
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aurora Sightings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'World'),
            Tab(text: 'Nearby'),
            Tab(text: 'Map'),
            Tab(text: 'My Profile'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FloatingActionButton.extended(
              onPressed: _navigateToSpotAurora,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add Sighting'),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildSightingsList(_recentSightings),
          _buildSightingsList(_nearbySightings),
          _buildMapView(),
          _buildProfileView(),
        ],
      ),
    );
  }

  Widget _buildSightingsList(List<AuroraSighting> sightings) {
    // Custom filter: always show at least the last 5, and if more than 5 in last 12 hours, show all from last 12 hours
    final now = DateTime.now();
    final twelveHoursAgo = now.subtract(const Duration(hours: 12));
    final recent = sightings.where((s) => s.timestamp.isAfter(twelveHoursAgo)).toList();
    List<AuroraSighting> displayList;
    if (recent.length > 5) {
      displayList = recent;
    } else {
      // Always show at least the last 5
      displayList = List<AuroraSighting>.from(sightings.take(5));
    }
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: displayList.length + 1 + (displayList.length ~/ 5), // +1 for top ad, +1 ad every 5 posts
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Banner ad at the very top (PRODUCTION)
                  return const AdMobBannerCard(adUnitId: 'ca-app-pub-4178524691208335/6625766838');
                }
                // Insert banner ad every 5 posts (after the top ad, PRODUCTION)
                if (index > 0 && (index % 6 == 0)) {
                  return const AdMobBannerCard(adUnitId: 'ca-app-pub-4178524691208335/6625766838');
                }
                // Calculate the correct post index, accounting for ads
                final numAdsBefore = (index > 0) ? ((index) ~/ 6) : 0;
                final postIndex = index - numAdsBefore - 1;
                if (postIndex < 0 || postIndex >= displayList.length) return const SizedBox.shrink();
                final sighting = displayList[postIndex];
                return AuroraPostCard(
                  sighting: sighting,
                  onLike: (sightingId) async {
                    try {
                      final result = await _firebaseService.confirmAuroraSighting(sightingId);
                      if (mounted) {
                        setState(() {
                          final idx = displayList.indexWhere((s) => s.id == sightingId);
                          if (idx != -1) {
                            displayList[idx] = displayList[idx].copyWith(
                              confirmations: result['confirmations'],
                              confirmedByUsers: result['verifications'],
                              isVerified: result['confirmations'] >= 3,
                            );
                          }
                        });
                      }
                    } catch (e) {
                      // print('Error liking sighting: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to like sighting. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  onViewProfile: (userId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(userId: userId),
                      ),
                    );
                  },
                  onViewLocation: (location) {
                    _tabController.animateTo(2); // Switch to map tab
                    Future.delayed(const Duration(milliseconds: 100), () {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(
                          LatLng(location.latitude, location.longitude),
                          12,
                        ),
                      );
                    });
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
            const Text(
              'Location permission required to view map',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      );
    }

    return AuroraMap(
      currentLocation: _currentLocation!,
      sightings: _nearbySightings,
      onMapCreated: (controller) {
        setState(() {
          _mapController = controller;
        });
      },
      onSightingTapped: (sighting) {
        showModalBottomSheet(
          context: context,
          builder: (context) => AuroraPostCard(
            sighting: sighting,
            onLike: (sightingId) async {
              try {
                final result = await _firebaseService.confirmAuroraSighting(sightingId);
                if (mounted) {
                  setState(() {
                    final index = _nearbySightings.indexWhere((s) => s.id == sightingId);
                    if (index != -1) {
                      _nearbySightings[index] = _nearbySightings[index].copyWith(
                        confirmations: result['confirmations'],
                        confirmedByUsers: result['verifications'],
                        isVerified: result['confirmations'] >= 3,
                      );
                    }
                  });
                }
              } catch (e) {
                // print('Error liking sighting: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to like sighting. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            onViewProfile: (userId) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfileScreen(userId: userId),
                ),
              );
            },
            onViewLocation: (location) {
              Navigator.pop(context);
              _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(location.latitude, location.longitude),
                  15,
                ),
              );
            },
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

                  final photos = snapshot.data!.docs
                      .map((doc) => UserAuroraPhoto.fromFirestore(doc))
                      .toList();

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final photo = photos[index];
                      return _buildUserPhotoCard(photo);
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

  Widget _buildUserPhotoCard(UserAuroraPhoto photo) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firebaseService.firestore.collection('aurora_sightings').doc(photo.sightingId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final confirmations = data?['confirmations'] ?? 0;
        final commentCount = data?['commentCount'] ?? 0;
        return GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => DraggableScrollableSheet(
                initialChildSize: 0.95,
                minChildSize: 0.7,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) => AuroraPhotoViewer(
                  photo: photo,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      photo.photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey.withOpacity(0.2),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.tealAccent, strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.withOpacity(0.2),
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white54, size: 32),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                        ),
                      ),
                    ),
                  ),
                  // Likes and comments overlay
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$confirmations',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.comment, color: Colors.tealAccent, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$commentCount',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${photo.intensity}⭐',
                            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Location and date overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          photo.locationName,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          photo.formattedDate,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, shadows: const [Shadow(color: Colors.black, blurRadius: 4)]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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

  void _navigateToSpotAurora({bool photoRequired = true}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpotAuroraScreen(
          currentBzH: 0.0, // You should get this from your aurora data service
          currentKp: 0.0,  // You should get this from your aurora data service
          photoRequired: photoRequired,
        ),
      ),
    );
  }

  Future<void> initializeLocalNotifications() async {
    // Initialize local notifications settings and permissions
  }

  void showAuroraNearbyNotification(String title, String body) {
    // Show a local notification for a new nearby aurora sighting
  }

  void showHighActivityNotification(String title, String body) {
    // Show a local notification for high aurora activity
  }
}