// lib/screens/settings_tab.dart
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent,
                  shadows: [Shadow(color: Colors.tealAccent, blurRadius: 8)],
                ),
              ),

              const SizedBox(height: 24),

              // Account Section
              _buildSectionHeader('Account'),
              _buildSettingItem(
                icon: Icons.person,
                title: 'Profile',
                subtitle: _firebaseService.isAuthenticated
                    ? 'Manage your profile'
                    : 'Sign in to access profile',
                onTap: () {
                  // TODO: Navigate to profile screen
                },
              ),

              _buildSettingItem(
                icon: Icons.notifications,
                title: 'Notifications',
                subtitle: 'Aurora alerts and updates',
                onTap: () {
                  // TODO: Navigate to notification settings
                },
              ),

              const SizedBox(height: 16),

              // App Section
              _buildSectionHeader('App'),
              _buildSettingItem(
                icon: Icons.info,
                title: 'About',
                subtitle: 'App version and info',
                onTap: () {
                  _showAboutDialog();
                },
              ),

              _buildSettingItem(
                icon: Icons.help,
                title: 'Help & Support',
                subtitle: 'Get help using the app',
                onTap: () {
                  // TODO: Navigate to help screen
                },
              ),

              const Spacer(),

              // Sign Out Button (if signed in)
              if (_firebaseService.isAuthenticated) ...[
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _firebaseService.signOut();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Signed out successfully'),
                            backgroundColor: Colors.tealAccent,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      child: ListTile(
        leading: Icon(icon, color: Colors.tealAccent),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.tealAccent),
            const SizedBox(width: 8),
            const Text(
              'Aurora Viking App',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Track, capture, and share northern lights sightings with the aurora hunting community.\n\nVersion 1.0.0',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.tealAccent),
            ),
          ),
        ],
      ),
    );
  }
}