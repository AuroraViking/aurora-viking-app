import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/firebase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  File? _profileImage;
  File? _bannerImage;
  bool _isLoading = false;
  String? _currentProfileUrl;
  String? _currentBannerUrl;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        final doc = await _firebaseService.firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          _displayNameController.text = data['displayName'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _currentProfileUrl = data['profilePictureUrl'];
          _currentBannerUrl = data['bannerUrl'];
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool isProfile) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          if (isProfile) {
            _profileImage = File(pickedFile.path);
          } else {
            _bannerImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final user = _firebaseService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final updates = <String, dynamic>{
        'displayName': _displayNameController.text,
        'bio': _bioController.text,
        'lastUpdated': DateTime.now(),
      };

      // Upload profile picture if changed
      if (_profileImage != null) {
        print('Uploading profile picture...');
        final profilePictureUrl = await _firebaseService.updateProfilePicture(_profileImage!);
        updates['profilePictureUrl'] = profilePictureUrl;
        print('Profile picture uploaded successfully');
      }

      // Upload banner if changed
      if (_bannerImage != null) {
        print('Uploading banner image...');
        final bannerUrl = await _firebaseService.uploadBannerImage(_bannerImage!);
        updates['bannerUrl'] = bannerUrl;
        print('Banner image uploaded successfully');
      }

      // Update user profile in Firestore
      print('Updating Firestore document...');
      await _firebaseService.firestore.collection('users').doc(user.uid).update(updates);
      print('Firestore document updated successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Banner Image
                  GestureDetector(
                    onTap: () => _pickImage(false),
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        image: _bannerImage != null
                            ? DecorationImage(
                                image: FileImage(_bannerImage!),
                                fit: BoxFit.cover,
                              )
                            : _currentBannerUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_currentBannerUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                      ),
                      child: (_bannerImage == null && _currentBannerUrl == null)
                          ? const Center(
                              child: Icon(
                                Icons.add_photo_alternate,
                                size: 50,
                                color: Colors.white54,
                              ),
                            )
                          : null,
                    ),
                  ),

                  // Profile Picture
                  Transform.translate(
                    offset: const Offset(0, -50),
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _pickImage(true),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black,
                              width: 4,
                            ),
                            image: _profileImage != null
                                ? DecorationImage(
                                    image: FileImage(_profileImage!),
                                    fit: BoxFit.cover,
                                  )
                                : _currentProfileUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_currentProfileUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: (_profileImage == null && _currentProfileUrl == null)
                              ? const Icon(
                                  Icons.add_a_photo,
                                  size: 40,
                                  color: Colors.white54,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Display Name
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _displayNameController,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        hintText: 'Enter your display name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Bio
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _bioController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell us about yourself...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 