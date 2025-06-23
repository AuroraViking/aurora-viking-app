import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'dart:async';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseService _firebaseService = FirebaseService();

  static Future<void> initialize() async {
    // Request permission for local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request FCM permission
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  static Future<void> _saveFCMToken(String token) async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        await _firebaseService.firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token saved: $token');
      }
    } catch (e) {
      print('❌ Failed to save FCM token: $e');
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - navigate to appropriate screen
    print('Notification tapped: ${response.payload}');
    
    // Parse the payload to determine which screen to navigate to
    if (response.payload != null) {
      final payload = response.payload!;
      
      if (payload.contains('aurora_sighting')) {
        // Navigate to aurora sightings screen
        // You can implement navigation logic here
        print('Navigate to aurora sighting');
      } else if (payload.contains('high_activity')) {
        // Navigate to aurora alerts screen
        print('Navigate to high activity alerts');
      } else if (payload.contains('app_update')) {
        // Navigate to app update screen or open app store
        print('Navigate to app update');
      }
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Received foreground message: ${message.notification?.title}');
    
    // Show local notification for foreground messages
    if (message.notification != null) {
      showLocalNotification(
        title: message.notification!.title ?? 'Aurora Viking',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'aurora_viking_channel',
      'Aurora Viking Notifications',
      channelDescription: 'Notifications for aurora sightings and alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Send notification for new aurora sighting
  static Future<void> notifyNewAuroraSighting({
    required String userName,
    required String locationName,
    required int intensity,
    required GeoPoint location,
  }) async {
    try {
      // Get all users who should receive notifications
      final usersSnapshot = await _firebaseService.firestore
          .collection('users')
          .where('notificationSettings.alertNearby', isEqualTo: true)
          .get();

      final currentUser = _firebaseService.currentUser;
      if (currentUser == null) return;

      // Get current user's location
      final currentPosition = await Geolocator.getCurrentPosition();
      final currentLocation = GeoPoint(currentPosition.latitude, currentPosition.longitude);

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;
        final userId = userDoc.id;

        // Skip if it's the same user who posted the sighting
        if (userId == currentUser.uid) continue;

        // Check if user has alertNearby enabled
        final notificationSettings = userData['notificationSettings'] as Map<String, dynamic>?;
        final alertNearby = notificationSettings?['alertNearby'] ?? true;

        if (!alertNearby) continue;

        // Calculate distance between user and sighting
        final distance = Geolocator.distanceBetween(
          currentLocation.latitude,
          currentLocation.longitude,
          location.latitude,
          location.longitude,
        );

        // Only notify if within 50km radius
        if (distance <= 50000) {
          final title = 'Aurora Spotted Nearby! 🌌';
          final body = '$userName spotted aurora (${intensity}⭐) near $locationName';

          // Send local notification
          await showLocalNotification(
            title: title,
            body: body,
            payload: 'aurora_sighting',
          );

          // TODO: Send FCM push notification to other devices
          // This would require a Cloud Function to send to specific FCM tokens
          print('📱 Would send notification to user $userId: $title - $body');
        }
      }
    } catch (e) {
      print('❌ Error sending aurora sighting notifications: $e');
    }
  }

  // Send notification for high activity
  static Future<void> notifyHighActivity({
    required int sightingCount,
    required String location,
  }) async {
    try {
      final usersSnapshot = await _firebaseService.firestore
          .collection('users')
          .where('notificationSettings.highActivityAlert', isEqualTo: true)
          .get();

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;

        final title = 'High Aurora Activity! 🌟';
        final body = '$sightingCount aurora sightings reported near $location in the last hour';

        // Send local notification
        await showLocalNotification(
          title: title,
          body: body,
          payload: 'high_activity',
        );

        print('📱 Would send high activity notification: $title - $body');
      }
    } catch (e) {
      print('❌ Error sending high activity notifications: $e');
    }
  }

  // Send notification for app updates
  static Future<void> notifyAppUpdate({
    required String version,
    required String updateMessage,
  }) async {
    try {
      final usersSnapshot = await _firebaseService.firestore
          .collection('users')
          .where('notificationSettings.appUpdates', isEqualTo: true)
          .get();

      for (final userDoc in usersSnapshot.docs) {
        final title = 'App Update Available! 📱';
        final body = 'Aurora Viking v$version is now available. $updateMessage';

        await showLocalNotification(
          title: title,
          body: body,
          payload: 'app_update',
        );

        print('📱 Would send app update notification: $title - $body');
      }
    } catch (e) {
      print('❌ Error sending app update notifications: $e');
    }
  }

  // Update user's location in Firestore for distance calculations
  static Future<void> updateUserLocation() async {
    try {
      final user = _firebaseService.currentUser;
      if (user == null) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _firebaseService.firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'lastKnownLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      print('✅ User location updated for notifications');
    } catch (e) {
      print('❌ Failed to update user location: $e');
    }
  }

  // Start periodic location updates
  static Timer? _locationUpdateTimer;
  
  static void startLocationUpdates() {
    // Update location every 15 minutes
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      updateUserLocation();
    });
    
    // Also update immediately
    updateUserLocation();
  }
  
  static void stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }
} 