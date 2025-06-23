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
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Show my sightings to others'),
            value: showSightings,
            onChanged: (val) async {
              setState(() => showSightings = val);
              await _updateSetting(showSightings: val);
            },
          ),
          SwitchListTile(
            title: const Text('Allow comments on my sightings'),
            value: allowComments,
            onChanged: (val) async {
              setState(() => allowComments = val);
              await _updateSetting(allowComments: val);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Delete my account', style: TextStyle(color: Colors.red)),
            onTap: _deleteAccount,
          ),
        ],
      ),
    );
  }
}
