// lib/screens/my_photos_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/google_drive_service.dart';
import '../services/firebase_service.dart';
import '../services/user_photos_service.dart';
import '../models/tour_photo.dart';
import '../models/user_aurora_photo.dart';
import '../screens/prints_tab.dart' as prints;
import '../widgets/aurora_photo_viewer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class MyPhotosTab extends StatefulWidget {
  const MyPhotosTab({super.key});

  @override
  State<MyPhotosTab> createState() => _MyPhotosTabState();
}

class _MyPhotosTabState extends State<MyPhotosTab> {
  final FirebaseService _firebaseService = FirebaseService();
  int? selectedIntensity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'My Aurora Photos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent,
                  shadows: [Shadow(color: Colors.tealAccent, blurRadius: 8)],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // User Photos
            Expanded(
              child: _buildUserPhotosTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPhotosTab() {
    if (_firebaseService.currentUser == null) {
      return _buildSignInPrompt();
    }

    return Column(
      children: [
        // Simple filters for user photos
        _buildUserFilters(),
        const SizedBox(height: 16),

        // Firebase stream for user photos
        Expanded(
          child: StreamBuilder<List<UserAuroraPhoto>>(
            stream: UserPhotosService.getUserPhotosStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyUserPhotos();
              }

              final userPhotos = snapshot.data!
                  .where(_filterUserPhoto)
                  .toList();

              if (userPhotos.isEmpty) {
                return _buildEmptyUserPhotos();
              }

              return _buildUserPhotosGrid(userPhotos);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedIntensity,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1F2E),
                  hint: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Filter by intensity',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('All Intensities'),
                    ),
                    ...List.generate(5, (index) => index + 1).map(
                      (intensity) => DropdownMenuItem<int>(
                        value: intensity,
                        child: Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: _getIntensityColor(intensity),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text('$intensity Stars'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedIntensity = value;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {
              setState(() {
                selectedIntensity = null;
              });
            },
            icon: const Icon(Icons.clear_all, color: Colors.tealAccent),
            tooltip: 'Clear filters',
          ),
        ],
      ),
    );
  }

  bool _filterUserPhoto(UserAuroraPhoto photo) {
    if (selectedIntensity != null) {
      return photo.intensity == selectedIntensity;
    }
    return true;
  }

  Widget _buildUserPhotosGrid(List<UserAuroraPhoto> photos) {
    return GridView.builder(
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
  }

  Widget _buildUserPhotoCard(UserAuroraPhoto photo) {
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
                          '${photo.confirmations}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.comment, color: Colors.tealAccent, size: 16),
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
  }

  Widget _buildEmptyUserPhotos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt, size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No aurora photos yet',
            style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture your first aurora using the camera!',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Sign in to view your photos',
            style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            'Your aurora photos will appear here',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
}