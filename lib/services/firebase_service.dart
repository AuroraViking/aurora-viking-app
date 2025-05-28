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

  // Current user properties
  User? get currentUser => auth.currentUser;
  bool get isAuthenticated => currentUser != null && !currentUser!.isAnonymous;
  bool get isGuest => currentUser != null && currentUser!.isAnonymous;
  String get userDisplayName {
    if (currentUser == null) return 'Guest';
    if (isGuest) return 'Guest';
    return currentUser!.displayName ?? currentUser!.email ?? 'User';
  }

  // Initialize Firebase with automatic guest sign-in
  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Automatically sign in as guest if no user is signed in
    final firebaseService = FirebaseService();
    if (firebaseService.currentUser == null) {
      await firebaseService.signInAsGuest();
    }

    await firebaseService._setupMessaging();
    print('✅ Firebase initialized - User: ${firebaseService.userDisplayName}');
  }

  // AUTHENTICATION METHODS

  // Sign in as guest (replaces anonymous)
  Future<UserCredential?> signInAsGuest() async {
    try {
      final credential = await auth.signInAnonymously();
      print('✅ Signed in as guest');
      return credential;
    } catch (e) {
      print('❌ Guest sign in failed: $e');
      return null;
    }
  }

  // Email/password registration - converts guest to full user
  Future<UserCredential?> registerWithEmail(String email, String password, String displayName) async {
    try {
      UserCredential credential;

      // If user is currently a guest, link the account
      if (isGuest) {
        final emailCredential = EmailAuthProvider.credential(email: email, password: password);
        credential = await currentUser!.linkWithCredential(emailCredential);
        print('✅ Guest account converted to full user');
      } else {
        // Create new account
        credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      // Update display name
      await credential.user?.updateDisplayName(displayName);
      await _createUserProfile(credential.user!);

      return credential;
    } catch (e) {
      print('❌ Registration failed: $e');
      return null;
    }
  }

  // Email/password sign in
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('❌ Sign in failed: $e');
      return null;
    }
  }

  // Sign out - returns to guest mode
  Future<void> signOut() async {
    try {
      await auth.signOut();
      // Automatically sign back in as guest
      await signInAsGuest();
      print('✅ Signed out and returned to guest mode');
    } catch (e) {
      print('❌ Sign out failed: $e');
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user) async {
    try {
      await firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'isGuest': user.isAnonymous,
        'auroraSpottingCount': 0,
        'verificationCount': 0,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ User profile created/updated');
    } catch (e) {
      print('❌ Failed to create user profile: $e');
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
    if (currentUser == null) {
      await signInAsGuest();
    }

    try {
      String? photoUrl;

      // Upload photo if provided
      if (photoFile != null || photoBytes != null) {
        photoUrl = await _uploadAuroraPhoto(photoFile, photoBytes);
      }

      // Create sighting document
      final sightingRef = await firestore.collection('aurora_sightings').add({
        'userId': currentUser!.uid,
        'userDisplayName': userDisplayName,
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

      // Update user's sighting count (only for authenticated users)
      if (isAuthenticated) {
        await firestore.collection('users').doc(currentUser!.uid).update({
          'auroraSpottingCount': FieldValue.increment(1),
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      return sightingRef.id;
    } catch (e) {
      print('❌ Failed to submit aurora sighting: $e');
      return null;
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
    if (currentUser == null) return false;

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

          // Update user's verification count (only for authenticated users)
          if (isAuthenticated) {
            transaction.update(
              firestore.collection('users').doc(currentUser!.uid),
              {
                'verificationCount': FieldValue.increment(1),
                'lastActive': FieldValue.serverTimestamp(),
              },
            );
          }
        }
      });

      return true;
    } catch (e) {
      print('❌ Failed to verify sighting: $e');
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
      print('❌ Failed to upload photo: $e');
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
      print('❌ Failed to upload tour photo: $e');
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
      print('❌ Failed to get tour photos: $e');
      return [];
    }
  }

  // MESSAGING & NOTIFICATIONS

  // Setup FCM
  Future<void> _setupMessaging() async {
    // Request permission for notifications
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted permission for notifications');
    }

    // Get FCM token
    final token = await messaging.getToken();
    print('📱 FCM Token: $token');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Received foreground message: ${message.notification?.title}');
      // Handle the message (show local notification)
    });
  }

  // Subscribe to aurora alerts for location
  Future<void> subscribeToAuroraAlerts(String locationKey) async {
    await messaging.subscribeToTopic('aurora_alerts_$locationKey');
    print('🔔 Subscribed to aurora alerts for $locationKey');
  }

  // Send aurora alert to topic
  Future<void> sendAuroraAlert({
    required String locationKey,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // This would typically be done from a cloud function or admin SDK
    // For now, we'll store alert data in Firestore
    await firestore.collection('aurora_alerts').add({
      'locationKey': locationKey,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
    });
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

  // Get user's aurora photos stream (updated to match index)
  Stream<QuerySnapshot> getUserPhotoStream({
    String? userId,
    int limit = 20,
  }) {
    final targetUserId = userId ?? currentUser?.uid;
    if (targetUserId == null) {
      return Stream.empty();
    }

    return firestore
        .collection('user_aurora_photos')
        .where('userId', isEqualTo: targetUserId)
        .orderBy('capturedAt', descending: true)
        .limit(limit)
        .snapshots();
  }
}