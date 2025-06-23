import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool appUpdates = true;
  bool highActivityAlert = false;
  bool alertNearby = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _firebaseService.getUserNotificationSettings();
    setState(() {
      appUpdates = settings['appUpdates'] ?? true;
      highActivityAlert = settings['highActivityAlert'] ?? false;
      alertNearby = settings['alertNearby'] ?? false;
      _loading = false;
    });
  }

  Future<void> _updateSetting({
    bool? appUpdates,
    bool? highActivityAlert,
    bool? alertNearby,
  }) async {
    await _firebaseService.setUserNotificationSettings(
      appUpdates: appUpdates,
      highActivityAlert: highActivityAlert,
      alertNearby: alertNearby,
    );
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
        title: const Text('Notification Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('App Updates'),
            value: appUpdates,
            onChanged: (val) async {
              setState(() => appUpdates = val);
              await _updateSetting(appUpdates: val);
            },
          ),
          SwitchListTile(
            title: const Text('High activity alert'),
            value: highActivityAlert,
            onChanged: (val) async {
              setState(() => highActivityAlert = val);
              await _updateSetting(highActivityAlert: val);
            },
          ),
          SwitchListTile(
            title: const Text('Alert when users close to me spot aurora'),
            value: alertNearby,
            onChanged: (val) async {
              setState(() => alertNearby = val);
              await _updateSetting(alertNearby: val);
            },
          ),
        ],
      ),
    );
  }
}
