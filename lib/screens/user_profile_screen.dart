import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/aurora_sighting.dart';
import '../models/user_aurora_photo.dart';
import '../services/firebase_service.dart';
import '../widgets/aurora_post_card.dart';
import '../widgets/aurora_photo_viewer.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<AuroraSighting> _userSightings = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserSightings();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _firebaseService.firestore
          .collection('users')
          .doc(widget.userId)
          .get();

      if (mounted) {
        setState(() {
          _userData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserSightings() async {
    try {
      final querySnapshot = await _firebaseService.firestore
          .collection('aurora_sightings')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _userSightings = querySnapshot.docs
              .map((doc) => AuroraSighting.fromFirestore(doc))
              .toList();
        });
      }
    } catch (e) {
      print('Error loading user sightings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_userData == null) {
      return const Scaffold(
        body: Center(child: Text('User not found')),
      );
    }

    final displayName = _userData!['displayName'] as String? ?? 'Anonymous User';
    final profilePictureUrl = _userData!['profilePictureUrl'] as String?;
    final auroraSpottingCount = _userData!['auroraSpottingCount'] as int? ?? 0;
    final verificationCount = _userData!['verificationCount'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadUserData(),
            _loadUserSightings(),
          ]);
        },
        child: ListView(
          children: [
            // Banner Image
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blueAccent.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
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
                              displayName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 32),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
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

            // User's Sightings
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aurora Sightings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_userSightings.isEmpty)
                    const Center(
                      child: Text(
                        'No sightings yet',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _userSightings.length,
                      itemBuilder: (context, index) {
                        final sighting = _userSightings[index];
                        return AuroraPostCard(
                          sighting: sighting,
                          onLike: (sightingId) async {
                            try {
                              final result = await _firebaseService.confirmAuroraSighting(sightingId);
                              if (mounted) {
                                setState(() {
                                  final index = _userSightings.indexWhere((s) => s.id == sightingId);
                                  if (index != -1) {
                                    _userSightings[index] = _userSightings[index].copyWith(
                                      confirmations: result['confirmations'],
                                      confirmedByUsers: result['verifications'],
                                      isVerified: result['confirmations'] >= 3,
                                    );
                                  }
                                });
                              }
                            } catch (e) {
                              print('Error liking sighting: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to like sighting. Please try again.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          onViewProfile: (userId) {
                            // Handle profile view
                          },
                          onViewLocation: (location) {
                            // Handle location view
                          },
                        );
                      },
                    ),
                ],
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
              stream: _firebaseService.getUserPhotoStream(userId: widget.userId),
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
                                        Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${photo.confirmations}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.comment, color: Colors.tealAccent, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${photo.commentCount}',
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
                                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, shadows: [const Shadow(color: Colors.black, blurRadius: 4)]),
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.tealAccent,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
} 