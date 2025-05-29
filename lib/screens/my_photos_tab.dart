// lib/screens/my_photos_tab.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/google_drive_service.dart';
import '../services/firebase_service.dart';
import '../services/user_photos_service.dart';
import '../models/tour_photo.dart';
import '../models/user_aurora_photo.dart';
import '../screens/print_shop_tab.dart' as print_shop;

class MyPhotosTab extends StatefulWidget {
  const MyPhotosTab({super.key});

  @override
  State<MyPhotosTab> createState() => _MyPhotosTabState();
}

class _MyPhotosTabState extends State<MyPhotosTab>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;

  // Tour Photos (Google Drive) - your existing code
  List<TourPhoto> photos = [];
  bool isLoading = false;
  bool isAuthenticated = false;
  String? errorMessage;
  String searchQuery = '';
  DateTime? selectedDate;

  // User Aurora Photos (Firebase) - new functionality
  final FirebaseService _firebaseService = FirebaseService();
  int? selectedIntensity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Changed to 2 tabs
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Your existing methods stay the same
  Future<void> _checkAuthStatus() async {
    final authStatus = await GoogleDriveService.isAuthenticated();
    setState(() {
      isAuthenticated = authStatus;
    });
  }

  Future<void> _authenticateUser() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final success = await GoogleDriveService.authenticate();
      setState(() {
        isAuthenticated = success;
        isLoading = false;
      });

      if (success) {
        _loadPhotos();
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Authentication failed: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _loadPhotos() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final tourPhotos = await GoogleDriveService.fetchTourPhotos(
        searchQuery: searchQuery,
        date: selectedDate,
      );
      setState(() {
        photos = tourPhotos;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load photos: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.tealAccent,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      if (isAuthenticated) {
        _loadPhotos();
      }
    }
  }

  void _clearFilters() {
    setState(() {
      searchQuery = '';
      selectedDate = null;
      selectedIntensity = null;
    });
    if (isAuthenticated) {
      _loadPhotos();
    }
  }

  Future<void> _downloadPhoto(TourPhoto photo) async {
    try {
      await GoogleDriveService.downloadPhoto(photo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: ${photo.fileName}'),
            backgroundColor: Colors.tealAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

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

            // Tab Bar - NEW
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.camera_alt, size: 20),
                    text: 'My Captures',
                  ),
                  Tab(
                    icon: Icon(Icons.tour, size: 20),
                    text: 'Tour Photos',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Content - NEW
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUserPhotosTab(), // NEW TAB
                  _buildTourPhotosTab(), // YOUR EXISTING CODE
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW TAB - User Aurora Photos
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

  // YOUR EXISTING TAB - but cleaned up
  Widget _buildTourPhotosTab() {
    if (!isAuthenticated) {
      return _buildTourPhotoAuth();
    }

    return Column(
      children: [
        _buildTourFilters(),
        const SizedBox(height: 16),
        Expanded(child: _buildTourPhotosContent()),
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
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 6,
                itemBuilder: (context, index) {
                  final intensity = index == 0 ? null : index;
                  final isSelected = selectedIntensity == intensity;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        intensity == null ? 'All' : '$intensity⭐',
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          selectedIntensity = selected ? intensity : null;
                        });
                      },
                      backgroundColor: Colors.transparent,
                      selectedColor: Colors.tealAccent,
                      side: BorderSide(
                        color: isSelected ? Colors.tealAccent : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          IconButton(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear_all, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTourFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by tour name or date...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: Colors.tealAccent.withOpacity(0.8)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              onSubmitted: (_) => _loadPhotos(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    selectedDate != null
                        ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                        : 'Select Date',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.tealAccent,
                    side: BorderSide(color: Colors.tealAccent.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _loadPhotos,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.black),
                label: const Text('Search', style: TextStyle(fontSize: 12, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _filterUserPhoto(UserAuroraPhoto photo) {
    if (selectedIntensity != null && photo.intensity != selectedIntensity) {
      return false;
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      return photo.locationName.toLowerCase().contains(query) ||
          (photo.metadata['description']?.toString().toLowerCase().contains(query) ?? false);
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
    return Container(
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
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getIntensityColor(photo.intensity).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${photo.intensity}⭐',
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    photo.locationName,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    photo.formattedDate,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () => _openPrintShop(photo),
                  icon: const Icon(Icons.print, color: Colors.black, size: 16),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Print this photo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.tealAccent.withOpacity(0.1), Colors.black.withOpacity(0.8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, size: 64, color: Colors.tealAccent.withOpacity(0.8)),
            const SizedBox(height: 16),
            const Text(
              'Capture Aurora Photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Use the "Spot Aurora" button to capture and share your aurora sightings. Your photos will appear here!',
              style: TextStyle(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
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

  // Your existing tour photos UI methods (unchanged)
  Widget _buildTourPhotoAuth() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.tealAccent.withOpacity(0.1), Colors.black.withOpacity(0.8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.tealAccent.withOpacity(0.8)),
            const SizedBox(height: 16),
            const Text(
              'Access Your Tour Photos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect to your Google Drive to view and download photos from your aurora tour.',
              style: TextStyle(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: isLoading ? null : _authenticateUser,
              icon: isLoading ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              ) : const Icon(Icons.login, color: Colors.black),
              label: Text(
                isLoading ? 'Connecting...' : 'Connect to Google Drive',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTourPhotosContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.tealAccent),
            SizedBox(height: 16),
            Text('Loading your photos...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadPhotos, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No photos found', style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8))),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search criteria or check back later.',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPhotos,
      color: Colors.tealAccent,
      backgroundColor: Colors.black,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return _buildPhotoCard(photo);
        },
      ),
    );
  }

  Widget _buildPhotoCard(TourPhoto photo) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                photo.thumbnailUrl,
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
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.white54, size: 32)),
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
            Positioned(
              bottom: 8, left: 8, right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    photo.tourName,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    photo.formattedDate,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () => _downloadPhoto(photo),
                  icon: const Icon(Icons.download, color: Colors.black, size: 16),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
            ),
          ],
        ),
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

  void _openPrintShop(UserAuroraPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => print_shop.PrintShopTab(preSelectedPhoto: photo),
      ),
    );
  }
}