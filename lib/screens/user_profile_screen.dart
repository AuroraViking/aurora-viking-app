import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/aurora_sighting.dart';
import '../services/firebase_service.dart';
import '../widgets/aurora_post_card.dart';

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