// lib/services/aurora_community_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/aurora_sighting.dart';

class AuroraCommunityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Submit a new aurora sighting
  static Future<String> submitSighting({
    required GeoPoint location,
    required String locationName,
    required int intensity,
    String? description,
    List<File>? photos,
    Map<String, dynamic>? weather,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Upload photos if provided
      List<String> photoUrls = [];
      if (photos != null && photos.isNotEmpty) {
        photoUrls = await _uploadPhotos(photos);
      }

      // Create sighting document
      final sighting = AuroraSighting(
        id: '', // Will be set by Firestore
        userId: user.uid,
        userName: user.displayName ?? 'Anonymous',
        timestamp: DateTime.now(),
        location: location,
        locationName: locationName,
        intensity: intensity,
        description: description,
        photoUrls: photoUrls,
        confirmations: 0,
        confirmedByUsers: [],
        isVerified: false,
        weather: weather ?? {},
      );

      // Add to Firestore
      final docRef = await _firestore
          .collection('aurora_sightings')
          .add(sighting.toFirestore());

      // Create alert for nearby users
      await _createAuroraAlert(
        sightingId: docRef.id,
        type: AlertType.firstSighting,
        location: location,
        intensity: intensity,
      );

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to submit sighting: ${e.toString()}');
    }
  }

  /// Get recent aurora sightings
  static Stream<List<AuroraSighting>> getRecentSightings({
    int limit = 50,
    Duration maxAge = const Duration(hours: 24),
  }) {
    final cutoff = DateTime.now().subtract(maxAge);

    return _firestore
        .collection('aurora_sightings')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AuroraSighting.fromFirestore(doc))
        .toList());
  }

  /// Get sightings near a location
  static Future<List<AuroraSighting>> getSightingsNearLocation({
    required GeoPoint center,
    required double radiusKm,
    Duration maxAge = const Duration(hours: 6),
  }) async {
    // Note: Firestore doesn't have built-in geo queries
    // For production, use GeoFlutterFire or similar package
    final cutoff = DateTime.now().subtract(maxAge);

    final snapshot = await _firestore
        .collection('aurora_sightings')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .get();

    return snapshot.docs
        .map((doc) => AuroraSighting.fromFirestore(doc))
        .where((sighting) => _calculateDistance(center, sighting.location) <= radiusKm)
        .toList();
  }

  /// Confirm/verify a sighting
  static Future<void> confirmSighting(String sightingId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final docRef = _firestore.collection('aurora_sightings').doc(sightingId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final sighting = AuroraSighting.fromFirestore(snapshot);

      // Check if user already confirmed
      if (sighting.confirmedByUsers.contains(user.uid)) {
        throw Exception('Already confirmed by this user');
      }

      // Update confirmations
      final updatedConfirmedBy = [...sighting.confirmedByUsers, user.uid];
      final updatedConfirmations = sighting.confirmations + 1;

      // Auto-verify if enough confirmations
      final isVerified = updatedConfirmations >= 3;

      transaction.update(docRef, {
        'confirmations': updatedConfirmations,
        'confirmedByUsers': updatedConfirmedBy,
        'isVerified': isVerified,
      });

      // Create confirmation alert
      if (updatedConfirmations == 3) {
        await _createAuroraAlert(
          sightingId: sightingId,
          type: AlertType.confirmation,
          location: sighting.location,
          intensity: sighting.intensity,
        );
      }
    });
  }

  /// Report intensity change
  static Future<void> reportIntensityChange({
    required String sightingId,
    required int newIntensity,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final docRef = _firestore.collection('aurora_sightings').doc(sightingId);
    final snapshot = await docRef.get();
    final sighting = AuroraSighting.fromFirestore(snapshot);

    if (newIntensity != sighting.intensity) {
      // Create new sighting for intensity change
      await submitSighting(
        location: sighting.location,
        locationName: sighting.locationName,
        intensity: newIntensity,
        description: 'Updated intensity from ${sighting.intensityDescription}',
      );

      // Create intensity change alert
      await _createAuroraAlert(
        sightingId: sightingId,
        type: newIntensity > sighting.intensity
            ? AlertType.intensityIncrease
            : AlertType.intensityDecrease,
        location: sighting.location,
        intensity: newIntensity,
      );
    }
  }

  /// Get user's sighting history
  static Future<List<AuroraSighting>> getUserSightings() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final snapshot = await _firestore
        .collection('aurora_sightings')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AuroraSighting.fromFirestore(doc))
        .toList();
  }

  /// Upload photos to Firebase Storage
  static Future<List<String>> _uploadPhotos(List<File> photos) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    List<String> urls = [];

    for (int i = 0; i < photos.length; i++) {
      final file = photos[i];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'aurora_sightings/${user.uid}/$timestamp-$i.jpg';

      final ref = _storage.ref().child(fileName);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();

      urls.add(url);
    }

    return urls;
  }

  /// Create aurora alert for nearby users
  static Future<void> _createAuroraAlert({
    required String sightingId,
    required AlertType type,
    required GeoPoint location,
    required int intensity,
  }) async {
    final alert = AuroraAlert(
      id: '',
      sightingId: sightingId,
      type: type,
      location: location,
      radiusKm: _getAlertRadius(intensity),
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(hours: _getAlertDuration(type))),
      isActive: true,
      message: _getAlertMessage(type, intensity),
      metadata: {
        'intensity': intensity,
        'type': type.toString(),
      },
    );

    await _firestore.collection('aurora_alerts').add(alert.toFirestore());

    // TODO: Trigger push notifications to users in radius
    await _sendPushNotifications(alert);
  }

  /// Get alert radius based on intensity
  static double _getAlertRadius(int intensity) {
    switch (intensity) {
      case 1: return 25.0; // 25km for faint aurora
      case 2: return 50.0; // 50km for weak aurora
      case 3: return 75.0; // 75km for moderate aurora
      case 4: return 100.0; // 100km for strong aurora
      case 5: return 150.0; // 150km for exceptional aurora
      default: return 50.0;
    }
  }

  /// Get alert duration in hours
  static int _getAlertDuration(AlertType type) {
    switch (type) {
      case AlertType.firstSighting: return 3;
      case AlertType.confirmation: return 2;
      case AlertType.intensityIncrease: return 4;
      case AlertType.intensityDecrease: return 1;
      case AlertType.nearbyActivity: return 2;
    }
  }

  /// Generate alert message
  static String _getAlertMessage(AlertType type, int intensity) {
    final intensityDesc = _getIntensityDescription(intensity);

    switch (type) {
      case AlertType.firstSighting:
        return '🌌 $intensityDesc aurora spotted nearby!';
      case AlertType.confirmation:
        return '✅ $intensityDesc aurora confirmed by multiple users!';
      case AlertType.intensityIncrease:
        return '⬆️ Aurora intensity increased to $intensityDesc!';
      case AlertType.intensityDecrease:
        return '⬇️ Aurora intensity decreased to $intensityDesc';
      case AlertType.nearbyActivity:
        return '📍 $intensityDesc aurora activity in your area!';
    }
  }

  /// Get intensity description
  static String _getIntensityDescription(int intensity) {
    switch (intensity) {
      case 1: return 'Faint';
      case 2: return 'Weak';
      case 3: return 'Moderate';
      case 4: return 'Strong';
      case 5: return 'EXCEPTIONAL';
      default: return 'Unknown';
    }
  }

  /// Calculate distance between two coordinates (simplified)
  static double _calculateDistance(GeoPoint point1, GeoPoint point2) {
    // Simplified distance calculation using Haversine formula
    const double earthRadius = 6371.0; // Earth's radius in km

    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLat = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLon = (point2.longitude - point1.longitude) * (pi / 180);

    final a = (deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * (deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  /// Send push notifications (placeholder)
  static Future<void> _sendPushNotifications(AuroraAlert alert) async {
    // TODO: Implement FCM push notifications
    // This would query users within the alert radius and send notifications
    print('📱 Sending push notification: ${alert.message}');
  }

  /// Check if conditions are good for spotting
  static bool shouldShowSpotButton({
    required double bzH,
    required double kp,
  }) {
    return bzH > 2.0 || kp > 2.5;
  }

  /// Get current aurora activity level
  static String getActivityLevel(List<AuroraSighting> recentSightings) {
    if (recentSightings.isEmpty) return 'No Activity';

    final activeSightings = recentSightings
        .where((s) => s.isActive)
        .toList();

    if (activeSightings.isEmpty) return 'Low Activity';

    final maxIntensity = activeSightings
        .map((s) => s.intensity)
        .reduce((a, b) => a > b ? a : b);

    switch (maxIntensity) {
      case 1: return 'Minimal Activity';
      case 2: return 'Low Activity';
      case 3: return 'Moderate Activity';
      case 4: return 'High Activity';
      case 5: return 'EXCEPTIONAL Activity';
      default: return 'Unknown Activity';
    }
  }
}