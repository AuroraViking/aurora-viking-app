import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool showSightings = true;
  bool allowComments = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;
    final doc = await _firebaseService.firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    setState(() {
      showSightings = data['showSightings'] ?? true;
      allowComments = data['allowComments'] ?? true;
      _loading = false;
    });
  }

  Future<void> _updateSetting({bool? showSightings, bool? allowComments}) async {
    final user = _firebaseService.currentUser;
    if (user == null) return;
    final updates = <String, dynamic>{};
    if (showSightings != null) updates['showSightings'] = showSightings;
    if (allowComments != null) updates['allowComments'] = allowComments;
    if (updates.isNotEmpty) {
      await _firebaseService.firestore.collection('users').doc(user.uid).update(updates);
    }
  }

  Future<void> _deleteAccount() async {
    final user = _firebaseService.currentUser;
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await _firebaseService.firestore.collection('users').doc(user.uid).delete();
      await _firebaseService.currentUser?.delete();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0F1C),
        body: Center(child: CircularProgressIndicator(color: Colors.tealAccent)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Privacy Settings',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.purpleAccent.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.privacy_tip, color: Colors.purpleAccent, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Privacy Preferences',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Control how your information is shared with others',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Privacy options
          _buildPrivacyOption(
            title: 'Show my sightings to others',
            subtitle: 'Allow other users to see your aurora sightings',
            icon: Icons.visibility,
            value: showSightings,
            onChanged: (val) async {
              setState(() => showSightings = val);
              await _updateSetting(showSightings: val);
            },
          ),
          const SizedBox(height: 16),
          
          _buildPrivacyOption(
            title: 'Allow comments on my sightings',
            subtitle: 'Let other users comment on your aurora sightings',
            icon: Icons.comment,
            value: allowComments,
            onChanged: (val) async {
              setState(() => allowComments = val);
              await _updateSetting(allowComments: val);
            },
          ),
          const SizedBox(height: 32),
          
          // Danger zone
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Danger Zone',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDangerOption(
                  title: 'Delete my account',
                  subtitle: 'Permanently delete your account and all data',
                  icon: Icons.delete_forever,
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, color: Colors.purpleAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.purpleAccent,
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.grey.withOpacity(0.3),
      ),
    );
  }

  Widget _buildDangerOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Colors.red, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.red.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Colors.red,
        ),
      ),
    );
  }
}
