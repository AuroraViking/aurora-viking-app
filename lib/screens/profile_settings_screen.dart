import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import 'my_photos_tab.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_settings_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, int> _stats = {'sightings': 0, 'verifications': 0};
  String? _profilePictureUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _firebaseService.getUserStats();
      final profileUrl = await _firebaseService.getProfilePictureUrl();
      setState(() {
        _stats = stats;
        _profilePictureUrl = profileUrl;
      });
    } catch (e) {
      print('❌ Failed to load user data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _isLoading = true);
        final file = File(pickedFile.path);
        final url = await _firebaseService.updateProfilePicture(file);
        setState(() => _profilePictureUrl = url);
            }
    } catch (e) {
      print('❌ Failed to pick/upload image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile & Settings',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<String>(
        stream: _firebaseService.getUserTypeStream(),
        builder: (context, snapshot) {
          final userType = snapshot.data ?? 'guest';
          final displayName = _firebaseService.userDisplayName;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(20),
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
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.blueAccent.withOpacity(0.2),
                              backgroundImage: _profilePictureUrl != null
                                  ? NetworkImage(_profilePictureUrl!)
                                  : null,
                              child: _profilePictureUrl == null
                                  ? Icon(
                                      _getUserTypeIcon(userType),
                                      size: 40,
                                      color: Colors.blueAccent,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF0A0F1C),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getUserTypeColor(userType).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getUserTypeColor(userType).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _getUserTypeLabel(userType),
                                style: TextStyle(
                                  color: _getUserTypeColor(userType),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        context,
                        'Aurora Sightings',
                        _stats['sightings'].toString(),
                        Icons.photo_camera,
                        Colors.blueAccent,
                      ),
                      _buildStatItem(
                        context,
                        'Verifications',
                        _stats['verifications'].toString(),
                        Icons.check_circle,
                        Colors.greenAccent,
                      ),
                    ],
                  ),
                ),

                // Settings Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        context,
                        'Edit Profile',
                        Icons.edit,
                        Colors.blueAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        context,
                        'Notification Settings',
                        Icons.notifications,
                        Colors.orangeAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        context,
                        'Privacy Settings',
                        Icons.privacy_tip,
                        Colors.purpleAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PrivacySettingsScreen(),
                            ),
                          );
                        },
                      ),
                      if (userType == 'tour_participant')
                        _buildSettingsItem(
                          context,
                          'Tour Photos',
                          Icons.photo_library,
                          Colors.tealAccent,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MyPhotosTab(),
                              ),
                            );
                          },
                        ),
                      _buildSettingsItem(
                        context,
                        'Sign Out',
                        Icons.logout,
                        Colors.redAccent,
                        onTap: () async {
                          await _firebaseService.signOut();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                // Aurora Viking promo card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Card(
                    color: Colors.tealAccent.withOpacity(0.12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Want to join the creators of this app on a Northern Lights tour?\nAre you going to Iceland or would you like to go? ',
                            style: TextStyle(
                              color: Colors.tealAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () async {
                                final url = Uri.parse('https://auroraviking.com');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: const Text('Click here to learn more!'),
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
        },
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    {required VoidCallback onTap}
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: color,
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.white54,
        ),
      ),
    );
  }

  IconData _getUserTypeIcon(String userType) {
    switch (userType) {
      case 'tour_participant':
        return Icons.card_travel;
      case 'aurora_user':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  Color _getUserTypeColor(String userType) {
    switch (userType) {
      case 'tour_participant':
        return Colors.tealAccent;
      case 'aurora_user':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  String _getUserTypeLabel(String userType) {
    switch (userType) {
      case 'tour_participant':
        return 'Tour Participant';
      case 'aurora_user':
        return 'Aurora App User';
      default:
        return 'Guest';
    }
  }
} 