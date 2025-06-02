// lib/services/user_photos_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_aurora_photo.dart';

class UserPhotosService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get current user's aurora photos
  static Stream<List<UserAuroraPhoto>> getUserPhotosStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('user_aurora_photos')
        .where('userId', isEqualTo: user.uid)
        .orderBy('capturedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => UserAuroraPhoto.fromFirestore(doc))
        .toList());
  }

  /// Get all user photos (for admin/community features)
  static Stream<List<UserAuroraPhoto>> getAllPhotosStream({
    int limit = 50,
    Duration? maxAge,
  }) {
    Query query = _firestore
        .collection('user_aurora_photos')
        .where('isPublic', isEqualTo: true)
        .orderBy('capturedAt', descending: true)
        .limit(limit);

    if (maxAge != null) {
      final cutoff = DateTime.now().subtract(maxAge);
      query = query.where('capturedAt', isGreaterThan: Timestamp.fromDate(cutoff));
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => UserAuroraPhoto.fromFirestore(doc))
        .toList());
  }

  /// Save a user's aurora photo after sighting submission
  static Future<String?> saveUserPhoto({
    required String sightingId,
    required String photoUrl,
    required String locationName,
    required int intensity,
    required Map<String, dynamic> metadata,
    required double latitude,
    required double longitude,
    bool isPublic = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final photo = UserAuroraPhoto(
        id: '',
        userId: user.uid,
        userName: user.displayName ?? 'Aurora Hunter',
        sightingId: sightingId,
        photoUrl: photoUrl,
        thumbnailUrl: photoUrl, // Same for now, could generate thumbnail
        capturedAt: DateTime.now(),
        locationName: locationName,
        intensity: intensity,
        isPublic: isPublic,
        isAvailableForPrint: true,
        printCount: 0,
        metadata: metadata,
        latitude: latitude,
        longitude: longitude,
        confirmations: 0,
        commentCount: 0,
      );

      final docRef = await _firestore
          .collection('user_aurora_photos')
          .add(photo.toFirestore());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to save user photo: ${e.toString()}');
    }
  }

  /// Update photo settings (privacy, print availability)
  static Future<void> updatePhotoSettings({
    required String photoId,
    bool? isPublic,
    bool? isAvailableForPrint,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final updates = <String, dynamic>{};
      if (isPublic != null) updates['isPublic'] = isPublic;
      if (isAvailableForPrint != null) updates['isAvailableForPrint'] = isAvailableForPrint;

      if (updates.isNotEmpty) {
        await _firestore
            .collection('user_aurora_photos')
            .doc(photoId)
            .update(updates);
      }
    } catch (e) {
      throw Exception('Failed to update photo settings: ${e.toString()}');
    }
  }

  /// Increment print count when user orders a print
  static Future<void> incrementPrintCount(String photoId) async {
    try {
      await _firestore
          .collection('user_aurora_photos')
          .doc(photoId)
          .update({
        'printCount': FieldValue.increment(1),
        'lastPrintedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update print count: ${e.toString()}');
    }
  }

  /// Delete a user's photo
  static Future<void> deletePhoto(String photoId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get photo document to verify ownership and get storage path
      final photoDoc = await _firestore
          .collection('user_aurora_photos')
          .doc(photoId)
          .get();

      if (!photoDoc.exists) {
        throw Exception('Photo not found');
      }

      final photo = UserAuroraPhoto.fromFirestore(photoDoc);
      if (photo.userId != user.uid) {
        throw Exception('Not authorized to delete this photo');
      }

      // Delete from Storage (extract path from URL)
      try {
        final ref = _storage.refFromURL(photo.photoUrl);
        await ref.delete();
      } catch (e) {
        // Continue even if storage deletion fails
        print('Failed to delete from storage: $e');
      }

      // Delete from Firestore
      await _firestore
          .collection('user_aurora_photos')
          .doc(photoId)
          .delete();

    } catch (e) {
      throw Exception('Failed to delete photo: ${e.toString()}');
    }
  }

  /// Get photos by intensity for community features
  static Future<List<UserAuroraPhoto>> getPhotosByIntensity(int intensity) async {
    try {
      final snapshot = await _firestore
          .collection('user_aurora_photos')
          .where('isPublic', isEqualTo: true)
          .where('intensity', isEqualTo: intensity)
          .orderBy('capturedAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => UserAuroraPhoto.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get photos by intensity: ${e.toString()}');
    }
  }

  /// Get user's photo statistics
  static Future<Map<String, dynamic>> getUserPhotoStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final snapshot = await _firestore
          .collection('user_aurora_photos')
          .where('userId', isEqualTo: user.uid)
          .get();

      final photos = snapshot.docs
          .map((doc) => UserAuroraPhoto.fromFirestore(doc))
          .toList();

      final stats = <String, dynamic>{
        'totalPhotos': photos.length,
        'totalPrints': photos.fold<int>(0, (sum, photo) => sum + photo.printCount),
        'publicPhotos': photos.where((p) => p.isPublic).length,
        'intensityBreakdown': <int, int>{},
        'firstPhoto': photos.isNotEmpty
            ? photos.map((p) => p.capturedAt).reduce((a, b) => a.isBefore(b) ? a : b)
            : null,
        'lastPhoto': photos.isNotEmpty
            ? photos.map((p) => p.capturedAt).reduce((a, b) => a.isAfter(b) ? a : b)
            : null,
      };

      // Calculate intensity breakdown
      for (final photo in photos) {
        stats['intensityBreakdown'][photo.intensity] =
            (stats['intensityBreakdown'][photo.intensity] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to get photo stats: ${e.toString()}');
    }
  }

  /// Search user photos
  static Future<List<UserAuroraPhoto>> searchUserPhotos({
    String? locationQuery,
    int? minIntensity,
    int? maxIntensity,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      Query query = _firestore
          .collection('user_aurora_photos')
          .where('userId', isEqualTo: user.uid);

      if (minIntensity != null) {
        query = query.where('intensity', isGreaterThanOrEqualTo: minIntensity);
      }

      if (maxIntensity != null) {
        query = query.where('intensity', isLessThanOrEqualTo: maxIntensity);
      }

      if (startDate != null) {
        query = query.where('capturedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('capturedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query
          .orderBy('capturedAt', descending: true)
          .get();

      var photos = snapshot.docs
          .map((doc) => UserAuroraPhoto.fromFirestore(doc))
          .toList();

      // Client-side location filtering (Firestore doesn't support text search)
      if (locationQuery != null && locationQuery.isNotEmpty) {
        photos = photos.where((photo) =>
            photo.locationName.toLowerCase().contains(locationQuery.toLowerCase())
        ).toList();
      }

      return photos;
    } catch (e) {
      throw Exception('Failed to search photos: ${e.toString()}');
    }
  }

  /// Get popular community photos (most printed)
  static Future<List<UserAuroraPhoto>> getPopularPhotos({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('user_aurora_photos')
          .where('isPublic', isEqualTo: true)
          .where('isAvailableForPrint', isEqualTo: true)
          .orderBy('printCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => UserAuroraPhoto.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get popular photos: ${e.toString()}');
    }
  }

  /// Create a printable package from user photo
  static Future<Map<String, dynamic>> createPrintPackage({
    required String photoId,
    required List<String> productTypes, // ['poster', 'canvas', 'mug', etc.]
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Get photo details
      final photoDoc = await _firestore
          .collection('user_aurora_photos')
          .doc(photoId)
          .get();

      if (!photoDoc.exists) {
        throw Exception('Photo not found');
      }

      final photo = UserAuroraPhoto.fromFirestore(photoDoc);

      // Create print package metadata
      final package = {
        'photoId': photoId,
        'photoUrl': photo.photoUrl,
        'userId': user.uid,
        'userName': photo.userName,
        'locationName': photo.locationName,
        'intensity': photo.intensity,
        'capturedAt': photo.capturedAt.toIso8601String(),
        'productTypes': productTypes,
        'createdAt': DateTime.now().toIso8601String(),
        'metadata': {
          'auroraIntensity': photo.intensity,
          'location': photo.locationName,
          'photographer': photo.userName,
          'dateCaptured': photo.capturedAt.toIso8601String(),
        },
      };

      return package;
    } catch (e) {
      throw Exception('Failed to create print package: ${e.toString()}');
    }
  }
}