import 'package:flutter/material.dart';
import '../../models/tour.dart';
import '../../models/user_aurora_photo.dart';
import '../../screens/print_shop_tab.dart';

class TourPhotosGrid extends StatelessWidget {
  final Tour tour;

  const TourPhotosGrid({
    super.key,
    required this.tour,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Tour Photos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Photos Grid
          Expanded(
            child: tour.photoUrls.isEmpty
                ? const Center(
                    child: Text(
                      'No photos available yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: tour.photoUrls.length,
                    itemBuilder: (context, index) {
                      return _buildPhotoCard(context, tour.photoUrls[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(BuildContext context, String photoUrl) {
    return GestureDetector(
      onTap: () => _showPhotoOptions(context, photoUrl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.tealAccent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.white54, size: 32),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.print,
                    color: Colors.tealAccent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions(BuildContext context, String photoUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print, color: Colors.tealAccent),
              title: const Text(
                'Print Photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context); // Close options
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrintShopTab(
                      preSelectedPhoto: UserAuroraPhoto(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        userId: '', // Not available from tour context
                        userName: '', // Not available from tour context
                        sightingId: '', // Not available from tour context
                        photoUrl: photoUrl,
                        thumbnailUrl: photoUrl,
                        capturedAt: tour.date,
                        locationName: tour.location,
                        intensity: 3, // Default intensity
                        isPublic: true,
                        isAvailableForPrint: true,
                        printCount: 0,
                        lastPrintedAt: null,
                        metadata: const {},
                      ),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.tealAccent),
              title: const Text(
                'Download Photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context); // Close options
                // TODO: Implement photo download
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Download feature coming soon!'),
                    backgroundColor: Colors.tealAccent,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 