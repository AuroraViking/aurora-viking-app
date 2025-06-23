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
  bool spaceWeatherAlert = false;
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
      spaceWeatherAlert = settings['spaceWeatherAlert'] ?? false;
      _loading = false;
    });
  }

  Future<void> _updateSetting({
    bool? appUpdates,
    bool? highActivityAlert,
    bool? alertNearby,
    bool? spaceWeatherAlert,
  }) async {
    final settings = await _firebaseService.getUserNotificationSettings();
    
    // Update only the changed settings
    if (appUpdates != null) settings['appUpdates'] = appUpdates;
    if (highActivityAlert != null) settings['highActivityAlert'] = highActivityAlert;
    if (alertNearby != null) settings['alertNearby'] = alertNearby;
    if (spaceWeatherAlert != null) settings['spaceWeatherAlert'] = spaceWeatherAlert;
    
    await _firebaseService.setUserNotificationSettings(settings);
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
          'Notification Settings',
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
                  Colors.tealAccent.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.tealAccent, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Notification Preferences',
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
                  'Choose what notifications you want to receive',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Notification options
          _buildNotificationOption(
            title: 'App Updates',
            subtitle: 'Get notified about new app features and updates',
            icon: Icons.system_update,
            value: appUpdates,
            onChanged: (val) async {
              setState(() => appUpdates = val);
              await _updateSetting(appUpdates: val);
            },
          ),
          const SizedBox(height: 16),
          
          _buildNotificationOption(
            title: 'High Activity Alert',
            subtitle: 'Get notified when there\'s high aurora activity in your area',
            icon: Icons.trending_up,
            value: highActivityAlert,
            onChanged: (val) async {
              setState(() => highActivityAlert = val);
              await _updateSetting(highActivityAlert: val);
            },
          ),
          const SizedBox(height: 16),
          
          _buildNotificationOption(
            title: 'Nearby Aurora Alerts',
            subtitle: 'Get notified when someone spots aurora near your location',
            icon: Icons.location_on,
            value: alertNearby,
            onChanged: (val) async {
              setState(() => alertNearby = val);
              await _updateSetting(alertNearby: val);
            },
          ),
          const SizedBox(height: 16),
          
          _buildNotificationOption(
            title: 'Space Weather Alerts',
            subtitle: 'Get notified about space weather events',
            icon: Icons.cloud,
            value: spaceWeatherAlert,
            onChanged: (val) async {
              setState(() => spaceWeatherAlert = val);
              await _updateSetting(spaceWeatherAlert: val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationOption({
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
          color: Colors.tealAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(icon, color: Colors.tealAccent, size: 24),
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
        activeColor: Colors.tealAccent,
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: Colors.grey.withOpacity(0.3),
      ),
    );
  }
}
