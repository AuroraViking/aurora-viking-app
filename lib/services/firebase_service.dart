import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase instances
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;
  FirebaseMessaging get messaging => FirebaseMessaging.instance;

  // Current user
  User? get currentUser => auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    await FirebaseService()._setupMessaging();
  }

  // AUTHENTICATION METHODS

  // Anonymous sign in for guest users
  Future<UserCredential?> signInAnonymously() async {
    try {
      final credential = await auth.signInAnonymously();
      if (credential.user != null) {
        await _ensureUserProfileExists();
      }
      return credential;
    } catch (e) {
      print('Anonymous sign in failed: $e');
      return null;
    }
  }

  // Email/password registration
  Future<UserCredential?> registerWithEmail(String email, String password, String displayName) async {
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(displayName);
      await _createUserProfile(credential.user!);

      return credential;
    } catch (e) {
      print('Registration failed: $e');
      return null;
    }
  }

  // Email/password sign in
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _ensureUserProfileExists();
      }
      return credential;
    } catch (e) {
      print('Sign in failed: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await auth.signOut();
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user) async {
    try {
      await firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'isAnonymous': user.isAnonymous,
        'auroraSpottingCount': 0,
        'verificationCount': 0,
      });
      print('✅ User profile created for ${user.uid}');
    } catch (e) {
      print('❌ Failed to create user profile: $e');
    }
  }

  // Add this helper method to ensure user profile exists
  Future<void> _ensureUserProfileExists() async {
    if (!isAuthenticated) return;

    try {
      final userDoc = await firestore.collection('users').doc(currentUser!.uid).get();

      if (!userDoc.exists) {
        print('👤 Creating user profile...');
        await _createUserProfile(currentUser!);
        print('✅ User profile created');
      } else {
        print('👤 User profile already exists');
      }
    } catch (e) {
      print('⚠️ Error ensuring user profile exists: $e');
    }
  }

  // AURORA SIGHTING METHODS

  // Submit aurora sighting
  Future<String?> submitAuroraSighting({
    required double latitude,
    required double longitude,
    required String address,
    required int intensity,
    required String description,
    File? photoFile,
    Uint8List? photoBytes,
    required double bzH,
    required double kp,
    required double solarWindSpeed,
  }) async {
    if (!isAuthenticated) return null;

    try {
      print('🔄 Starting aurora sighting submission...');

      // Create user profile if it doesn't exist (fix for the document not found error)
      await _ensureUserProfileExists();

      String? photoUrl;

      // Upload photo if provided
      if (photoFile != null || photoBytes != null) {
        print('📸 Uploading photo...');
        photoUrl = await _uploadAuroraPhoto(photoFile, photoBytes);
        print('✅ Photo uploaded: $photoUrl');
      }

      print('💾 Creating sighting document...');
      // Create sighting document
      final sightingRef = await firestore.collection('aurora_sightings').add({
        'userId': currentUser!.uid,
        'userDisplayName': currentUser!.displayName ?? 'Aurora Hunter',
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        },
        'intensity': intensity,
        'description': description,
        'photoUrl': photoUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'weather': {
          'bzH': bzH,
          'kp': kp,
          'solarWindSpeed': solarWindSpeed,
        },
        'verifications': <String>[],
        'isVerified': false,
        'reportCount': 0,
      });

      print('✅ Sighting document created with ID: ${sightingRef.id}');

      // Save user photo if one was taken
      if (photoUrl != null) {
        print('💾 Saving user photo...');
        await _saveUserPhoto(
          sightingId: sightingRef.id,
          photoUrl: photoUrl,
          locationName: address,
          intensity: intensity,
          metadata: {
            'bzH': bzH,
            'kp': kp,
            'solarWindSpeed': solarWindSpeed,
            'description': description,
          },
        );
        print('✅ User photo saved');
      }

      // Update user's sighting count (now safe because profile exists)
      print('📊 Updating user stats...');
      await firestore.collection('users').doc(currentUser!.uid).update({
        'auroraSpottingCount': FieldValue.increment(1),
      });
      print('✅ User stats updated');

      print('🎉 Aurora sighting submission completed successfully!');
      return sightingRef.id;
    } catch (e) {
      print('❌ Failed to submit aurora sighting: $e');
      return null;
    }
  }

  // Save user photo to separate collection for print shop access
  Future<void> _saveUserPhoto({
    required String sightingId,
    required String photoUrl,
    required String locationName,
    required int intensity,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      await firestore.collection('user_aurora_photos').add({
        'userId': currentUser!.uid,
        'userName': currentUser!.displayName ?? 'Aurora Hunter',
        'sightingId': sightingId,
        'photoUrl': photoUrl,
        'thumbnailUrl': photoUrl, // Same for now, could generate thumbnail later
        'capturedAt': FieldValue.serverTimestamp(),
        'locationName': locationName,
        'intensity': intensity,
        'isPublic': true,
        'isAvailableForPrint': true,
        'printCount': 0,
        'metadata': metadata,
      });
    } catch (e) {
      print('Failed to save user photo: $e');
      // Don't throw - this is secondary to the main sighting submission
    }
  }

  // Get aurora sightings stream
  Stream<QuerySnapshot> getAuroraSightingsStream({
    int limit = 50,
    DateTime? since,
  }) {
    Query query = firestore
        .collection('aurora_sightings')
        .orderBy('timestamp', descending: true)
        .limit(limit);

    if (since != null) {
      query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
    }

    return query.snapshots();
  }

  // Get nearby aurora sightings
  Future<List<DocumentSnapshot>> getNearbyAuroraSightings({
    required double latitude,
    required double longitude,
    double radiusKm = 100,
    int hours = 6,
  }) async {
    final since = DateTime.now().subtract(Duration(hours: hours));

    // Note: This is a simplified version. For production, use GeoFlutterFire for proper geo queries
    final snapshot = await firestore
        .collection('aurora_sightings')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    // Filter by distance (simplified calculation)
    return snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final location = data['location'] as Map<String, dynamic>;
      final distance = _calculateDistance(
        latitude, longitude,
        location['latitude'], location['longitude'],
      );
      return distance <= radiusKm;
    }).toList();
  }

  // Verify aurora sighting
  Future<bool> verifyAuroraSighting(String sightingId) async {
    if (!isAuthenticated) return false;

    try {
      final sightingRef = firestore.collection('aurora_sightings').doc(sightingId);

      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(sightingRef);
        final data = snapshot.data() as Map<String, dynamic>;

        final verifications = List<String>.from(data['verifications'] ?? []);

        if (!verifications.contains(currentUser!.uid)) {
          verifications.add(currentUser!.uid);

          transaction.update(sightingRef, {
            'verifications': verifications,
            'isVerified': verifications.length >= 3,
          });
        }
      });

      return true;
    } catch (e) {
      print('Failed to verify sighting: $e');
      return false;
    }
  }

  // PHOTO UPLOAD METHODS

  // Upload aurora photo
  Future<String?> _uploadAuroraPhoto(File? file, Uint8List? bytes) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'aurora_${currentUser!.uid}_$timestamp.jpg';
      final ref = storage.ref().child('aurora_photos/$fileName');

      UploadTask uploadTask;
      if (file != null) {
        uploadTask = ref.putFile(file);
      } else if (bytes != null) {
        uploadTask = ref.putData(bytes);
      } else {
        return null;
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Failed to upload photo: $e');
      return null;
    }
  }

  // Upload tour photo (for guides)
  Future<String?> uploadTourPhoto({
    required String tourId,
    required File photoFile,
    required String fileName,
  }) async {
    try {
      final ref = storage.ref().child('tour_photos/$tourId/$fileName');
      final uploadTask = ref.putFile(photoFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Failed to upload tour photo: $e');
      return null;
    }
  }

  // Get tour photos
  Future<List<String>> getTourPhotoUrls(String tourId) async {
    try {
      final ref = storage.ref().child('tour_photos/$tourId');
      final result = await ref.listAll();

      final urls = <String>[];
      for (final item in result.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }

      return urls;
    } catch (e) {
      print('Failed to get tour photos: $e');
      return [];
    }
  }

  // MESSAGING & NOTIFICATIONS

  // Setup FCM
  Future<void> _setupMessaging() async {
    try {
      // Request permission for notifications
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission for notifications');
      }

      // Get FCM token
      final token = await messaging.getToken();
      print('FCM Token: $token');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Received foreground message: ${message.notification?.title}');
        // Handle the message (show local notification)
      });
    } catch (e) {
      print('Error setting up messaging: $e');
    }
  }

  // Subscribe to aurora alerts for location
  Future<void> subscribeToAuroraAlerts(String locationKey) async {
    try {
      await messaging.subscribeToTopic('aurora_alerts_$locationKey');
    } catch (e) {
      print('Failed to subscribe to aurora alerts: $e');
    }
  }

  // Send aurora alert to topic
  Future<void> sendAuroraAlert({
    required String locationKey,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // This would typically be done from a cloud function or admin SDK
      // For now, we'll store alert data in Firestore
      await firestore.collection('aurora_alerts').add({
        'locationKey': locationKey,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to send aurora alert: $e');
    }
  }

  // USER PHOTOS METHODS

  // Get user's aurora photos
  Stream<QuerySnapshot> getUserPhotosStream() {
    if (!isAuthenticated) {
      // Return empty stream if not authenticated
      return Stream.value(
          QuerySnapshot as QuerySnapshot
      );
    }

    return firestore
        .collection('user_aurora_photos')
        .where('userId', isEqualTo: currentUser!.uid)
        .orderBy('capturedAt', descending: true)
        .snapshots();
  }

  // Update photo privacy settings
  Future<void> updatePhotoPrivacy(String photoId, bool isPublic) async {
    if (!isAuthenticated) return;

    try {
      await firestore
          .collection('user_aurora_photos')
          .doc(photoId)
          .update({'isPublic': isPublic});
    } catch (e) {
      print('Failed to update photo privacy: $e');
    }
  }

  // Delete user photo
  Future<void> deleteUserPhoto(String photoId) async {
    if (!isAuthenticated) return;

    try {
      // Get photo to verify ownership
      final photoDoc = await firestore
          .collection('user_aurora_photos')
          .doc(photoId)
          .get();

      if (photoDoc.exists) {
        final data = photoDoc.data() as Map<String, dynamic>;
        if (data['userId'] == currentUser!.uid) {
          // Delete from Storage if needed
          final photoUrl = data['photoUrl'] as String?;
          if (photoUrl != null) {
            try {
              final ref = storage.refFromURL(photoUrl);
              await ref.delete();
            } catch (e) {
              print('Failed to delete from storage: $e');
            }
          }

          // Delete from Firestore
          await firestore
              .collection('user_aurora_photos')
              .doc(photoId)
              .delete();
        }
      }
    } catch (e) {
      print('Failed to delete user photo: $e');
    }
  }

  // UTILITY METHODS

  // Calculate distance between two points (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}