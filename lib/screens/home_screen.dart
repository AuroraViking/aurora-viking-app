// Replace your home_screen.dart with this updated version

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../screens/camera_aurora_screen.dart';
import '../screens/forecast_tab.dart';
import '../screens/my_photos_tab.dart';
import '../screens/aurora_alerts_tab.dart';
import '../screens/print_shop_tab.dart';
import '../screens/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Changed from 4 to 5
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    // Your existing initialization code - but DON'T auto sign-in
    print('DEBUG: User authenticated: ${_firebaseService.isAuthenticated}');
    print('DEBUG: Current user: ${_firebaseService.currentUser?.uid}');

    // Remove any auto sign-in code from here
  }

  Future<void> _openCamera() async {
    if (!_firebaseService.isAuthenticated) {
      // Show message and navigate to community tab to sign in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please sign in first to report aurora sightings'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Sign In',
            textColor: Colors.white,
            onPressed: () {
              _tabController.animateTo(2); // Navigate to community tab
            },
          ),
        ),
      );
      return;
    }

    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraAuroraScreen(
            currentBzH: -5.0, // Default/placeholder values
            currentKp: 3.0,   // You can get real values from your aurora service
          ),
        ),
      );

      if (result == true) {
        // Success - show message and switch to community tab
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🌌 Aurora sighting reported successfully!'),
              backgroundColor: Colors.tealAccent,
            ),
          );
          _tabController.animateTo(2); // Switch to community tab
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open camera: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserStatus() {
    final user = _firebaseService.currentUser;

    if (!_firebaseService.isAuthenticated || user == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              'Guest',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _tabController.animateTo(2), // Navigate to community tab
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // User is signed in
    String displayName = 'Aurora Hunter';
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      displayName = user.displayName!;
    } else if (user.email != null && user.email!.isNotEmpty) {
      displayName = user.email!.split('@')[0];
    } else if (user.isAnonymous) {
      displayName = 'Hunter #${user.uid.substring(0, 4)}';
    }

    return GestureDetector(
      onTap: () => _showUserMenu(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.tealAccent.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.2),
              ),
              child: Icon(
                user.isAnonymous ? Icons.person_outline : Icons.person,
                color: Colors.black,
                size: 12,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              displayName,
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, color: Colors.black, size: 16),
          ],
        ),
      ),
    );
  }

  void _showUserMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person, color: Colors.tealAccent),
              title: Text('Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile screen if you have one
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Sign Out', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await _firebaseService.signOut();
                setState(() {}); // Refresh the UI
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Signed out successfully'),
                    backgroundColor: Colors.tealAccent,
                  ),
                );
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _firebaseService.auth.authStateChanges(),
      builder: (context, authSnapshot) {
        return Scaffold(
          backgroundColor: Colors.black,
          // Your existing body content goes here
          body: Stack(
            children: [
              // Your main tab content
              TabBarView(
                controller: _tabController,
                children: [
                  const ForecastTab(),
                  const MyPhotosTab(),
                  const AuroraAlertsTab(),
                  const PrintShopTab(),
                  const SettingsTab(),
                ],
              ),

              // User status widget - positioned in bottom right above tabs
              Positioned(
                bottom: 80, // Reduced from 100 to sit closer to tabs
                right: 16,
                child: _buildUserStatus(),
              ),
            ],
          ),

          // Your existing bottom navigation
          bottomNavigationBar: Container(
            color: Colors.black,
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(icon: Icon(Icons.wb_sunny), text: 'Forecast'),
                Tab(icon: Icon(Icons.photo_library), text: 'Photos'),
                Tab(icon: Icon(Icons.group), text: 'Community'),
                Tab(icon: Icon(Icons.shopping_cart), text: 'Print Shop'),
                Tab(icon: Icon(Icons.settings), text: 'Settings'),
              ],
              labelColor: Colors.tealAccent,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.tealAccent,
            ),
          ),

          // Report Aurora button
          floatingActionButton: Container(
            margin: EdgeInsets.only(bottom: 20), // Add margin to lift above tabs
            child: FloatingActionButton.extended(
              onPressed: _openCamera,
              backgroundColor: Color(0xFF00D4AA),
              foregroundColor: Colors.black,
              icon: Icon(Icons.add_a_photo),
              label: Text(
                'REPORT AURORA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}