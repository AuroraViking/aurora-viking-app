import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import '../services/user_photos_service.dart';
import '../services/bokun_service.dart';
import '../models/aurora_sighting.dart';
import '../models/aurora_comment.dart';

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
  bool get isAuthenticated => currentUser != null;
  String get userDisplayName {
    if (currentUser == null) return 'Not Signed In';
    return currentUser!.displayName ?? currentUser!.email ?? 'User';
  }

  // Initialize Firebase
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    await FirebaseService()._setupMessaging();
    print('✅ Firebase initialized');
  }

  // AUTHENTICATION METHODS

  // Email/password registration
  Future<UserCredential?> registerWithEmail(String email, String password, String displayName) async {
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

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
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user type in Firestore
      if (credential.user != null) {
        await firestore.collection('users').doc(credential.user!.uid).update({
          'userType': 'aurora_user',
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      return credential;
    } catch (e) {
      print('❌ Sign in failed: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await auth.signOut();
      print('✅ Signed out successfully');
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
        'auroraSpottingCount': 0,
        'verificationCount': 0,
        'lastActive': FieldValue.serverTimestamp(),
        'userType': 'aurora_user',
        'tourParticipant': false,
        'tourBookings': [],
        'verifiedTourEmail': null,
      }, SetOptions(merge: true));

      print('✅ User profile created/updated');
    } catch (e) {
      print('❌ Failed to create user profile: $e');
    }
  }

  // TOUR VERIFICATION METHODS

  // Verify tour participant by email (for compatibility with your existing screen)
  Future<Map<String, dynamic>?> verifyTourParticipant(String email) async {
    try {
      print('🔍 Verifying tour participant by email: $email');

      // First check if we have any verified bookings in Firestore that match this email
      final verifiedBookings = await _checkFirestoreForVerifiedBooking(email);
      if (verifiedBookings != null) {
        return verifiedBookings;
      }

      // If not found in Firestore, try to find in Bokun by searching all bookings
      // Note: This is a fallback - in real implementation you'd have email-to-booking mapping
      print('🔍 Searching Bokun for email: $email');

      // For now, we'll use a test booking reference - replace this with actual email lookup
      final testBookingRef = 'aur-65391772'; // Your test booking
      final bookingDetails = await BokunService.verifyBookingReference(testBookingRef);

      if (bookingDetails != null && bookingDetails['isValid'] == true) {
        // Store the verified booking in Firestore
        await _storeVerifiedBooking(email, testBookingRef, bookingDetails);
        return bookingDetails;
      }

      return null;
    } catch (e) {
      print('❌ Error verifying tour participant by email: $e');
      throw e;
    }
  }

  // Verify tour participant by booking reference
  Future<Map<String, dynamic>?> verifyTourParticipantByReference(String reference) async {
    try {
      print('🔍 Verifying tour participant by reference: $reference');

      // First verify the booking exists in Bokun
      final bookingDetails = await BokunService.verifyBookingReference(reference);

      if (bookingDetails != null && bookingDetails['isValid'] == true) {
        // Store the verification in Firestore
        await _storeVerifiedBookingByReference(reference, bookingDetails);
        return bookingDetails;
      }

      return null;
    } catch (e) {
      print('❌ Error verifying tour participant by reference: $e');
      throw e;
    }
  }

  // Check Firestore for existing verified booking by email
  Future<Map<String, dynamic>?> _checkFirestoreForVerifiedBooking(String email) async {
    try {
      final snapshot = await firestore
          .collection('verified_bookings')
          .where('email', isEqualTo: email.toLowerCase())
          .where('isValid', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        print('✅ Found verified booking in Firestore for email: $email');
        return data;
      }
    } catch (e) {
      print('❌ Error checking Firestore for verified booking: $e');
    }
    return null;
  }

  // Store verified booking in Firestore
  Future<void> _storeVerifiedBooking(String email, String reference, Map<String, dynamic> bookingDetails) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Store in verified_bookings collection
      await firestore.collection('verified_bookings').add({
        'email': email.toLowerCase(),
        'bookingReference': reference,
        'bookingDetails': bookingDetails,
        'isValid': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': user?.uid,
      });

      // Update user profile if user is logged in
      if (user != null) {
        await firestore.collection('users').doc(user.uid).update({
          'hasVerifiedBooking': true,
          'bookingReference': reference,
          'verifiedTourEmail': email.toLowerCase(),
          'bookingDetails': bookingDetails,
          'lastVerified': FieldValue.serverTimestamp(),
          'tourParticipant': true,
        });
      }

      print('✅ Stored verified booking for email: $email');
    } catch (e) {
      print('❌ Error storing verified booking: $e');
    }
  }

  // Store verified booking by reference
  Future<void> _storeVerifiedBookingByReference(String reference, Map<String, dynamic> bookingDetails) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Extract email from booking details if available
      String? email;
      if (bookingDetails['customerEmail'] != null) {
        email = bookingDetails['customerEmail'].toString().toLowerCase();
      }

      // Store in verified_bookings collection
      await firestore.collection('verified_bookings').add({
        'email': email,
        'bookingReference': reference,
        'bookingDetails': bookingDetails,
        'isValid': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': user?.uid,
      });

      // Update user profile if user is logged in
      if (user != null) {
        await firestore.collection('users').doc(user.uid).update({
          'hasVerifiedBooking': true,
          'bookingReference': reference,
          'verifiedTourEmail': email,
          'bookingDetails': bookingDetails,
          'lastVerified': FieldValue.serverTimestamp(),
          'tourParticipant': true,
        });
      }

      print('✅ Stored verified booking for reference: $reference');
    } catch (e) {
      print('❌ Error storing verified booking by reference: $e');
    }
  }

  // Get user type
  Future<String> getUserType() async {
    if (currentUser == null) return 'guest';

    try {
      final doc = await firestore.collection('users').doc(currentUser!.uid).get();
      return doc.data()?['userType'] ?? 'aurora_user';
    } catch (e) {
      print('❌ Failed to get user type: $e');
      return 'aurora_user';
    }
  }

  // Check if user is tour participant
  Future<bool> isTourParticipant() async {
    if (currentUser == null) return false;

    try {
      final doc = await firestore.collection('users').doc(currentUser!.uid).get();
      return doc.data()?['tourParticipant'] ?? false;
    } catch (e) {
      print('❌ Failed to check tour participant status: $e');
      return false;
    }
  }

  // Get user's verified booking details
  Future<Map<String, dynamic>?> getUserVerifiedBooking() async {
    if (currentUser == null) return null;

    try {
      final doc = await firestore.collection('users').doc(currentUser!.uid).get();
      return doc.data()?['bookingDetails'];
    } catch (e) {
      print('❌ Failed to get user verified booking: $e');
      return null;
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
      return null;
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
        'location': GeoPoint(latitude, longitude),
        'locationName': address,
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
        'confirmations': 0,
        'isVerified': false,
        'reportCount': 0,
      });

      // Update user's profile with location and sighting count
      if (isAuthenticated) {
        await firestore.collection('users').doc(currentUser!.uid).update({
          'auroraSpottingCount': FieldValue.increment(1),
          'lastActive': FieldValue.serverTimestamp(),
          'location': GeoPoint(latitude, longitude),
          'lastLocationName': address,
        });
      }

      // Also save as user photo if photo was uploaded
      if (photoUrl != null) {
        await UserPhotosService.saveUserPhoto(
          sightingId: sightingRef.id,
          photoUrl: photoUrl,
          locationName: address,
          intensity: intensity,
          metadata: {
            'description': description,
            'weather': {
              'bzH': bzH,
              'kp': kp,
              'solarWindSpeed': solarWindSpeed,
            },
          },
        );
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

  // Get user type stream
  Stream<String> getUserTypeStream() {
    if (currentUser == null) return Stream.value('not_signed_in');

    return firestore
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return 'aurora_user';
      final data = doc.data() ?? {};
      return data['userType'] ?? 'aurora_user';
    });
  }

  // Update user type
  Future<void> updateUserType(String userType) async {
    if (currentUser == null) return;

    try {
      await firestore.collection('users').doc(currentUser!.uid).update({
        'userType': userType,
        'lastActive': FieldValue.serverTimestamp(),
      });
      print('✅ User type updated to: $userType');
    } catch (e) {
      print('❌ Failed to update user type: $e');
    }
  }

  // Get user stats
  Future<Map<String, int>> getUserStats() async {
    if (currentUser == null) return {'sightings': 0, 'verifications': 0};

    try {
      final doc = await firestore.collection('users').doc(currentUser!.uid).get();
      final data = doc.data() ?? {};
      return {
        'sightings': data['auroraSpottingCount'] ?? 0,
        'verifications': data['verificationCount'] ?? 0,
      };
    } catch (e) {
      print('❌ Failed to get user stats: $e');
      return {'sightings': 0, 'verifications': 0};
    }
  }

  // Update profile picture
  Future<String> updateProfilePicture(File imageFile) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final storageRef = storage.ref().child('profile_pictures/${user.uid}');
    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Get profile picture URL
  Future<String?> getProfilePictureUrl() async {
    if (currentUser == null) return null;

    try {
      final doc = await firestore.collection('users').doc(currentUser!.uid).get();
      return doc.data()?['profilePictureUrl'];
    } catch (e) {
      print('❌ Failed to get profile picture URL: $e');
      return null;
    }
  }

  Future<List<AuroraComment>> getCommentsForSighting(String sightingId) async {
    try {
      final commentsSnapshot = await firestore
          .collection('aurora_sightings')
          .doc(sightingId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();

      return commentsSnapshot.docs
          .map((doc) => AuroraComment.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  Future<void> addComment({
    required String sightingId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['displayName'] ?? userDisplayName;

      final comment = AuroraComment(
        id: firestore.collection('aurora_sightings').doc().id,
        sightingId: sightingId,
        userId: user.uid,
        userName: userName,
        content: content,
        timestamp: DateTime.now(),
        likes: 0,
        replies: 0,
        parentCommentId: parentCommentId,
      );

      await firestore
          .collection('aurora_sightings')
          .doc(sightingId)
          .collection('comments')
          .doc(comment.id)
          .set(comment.toFirestore());
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  Future<List<AuroraSighting>> getNearbySightings() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user's location from their last sighting or profile
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userLocation = userDoc.data()?['location'] as GeoPoint?;

      if (userLocation == null) {
        // If no location in profile, try to get from last sighting
        final lastSighting = await firestore
            .collection('aurora_sightings')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (lastSighting.docs.isEmpty) {
          return [];
        }

        final sightingData = lastSighting.docs.first.data();
        final location = sightingData['location'] as GeoPoint;
        final latitude = location.latitude;
        final longitude = location.longitude;

        // Get all recent sightings and filter by distance
        final snapshot = await firestore
            .collection('aurora_sightings')
            .orderBy('timestamp', descending: true)
            .limit(100)
            .get();

        return snapshot.docs
            .map((doc) => AuroraSighting.fromFirestore(doc))
            .where((sighting) {
              final distance = _calculateDistance(
                latitude, longitude,
                sighting.location.latitude, sighting.location.longitude,
              );
              return distance <= 100; // 100km radius
            })
            .toList();
      }

      // If we have user location in profile, use that
      final snapshot = await firestore
          .collection('aurora_sightings')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      return snapshot.docs
          .map((doc) => AuroraSighting.fromFirestore(doc))
          .where((sighting) {
            final distance = _calculateDistance(
              userLocation.latitude, userLocation.longitude,
              sighting.location.latitude, sighting.location.longitude,
            );
            return distance <= 100; // 100km radius
          })
          .toList();
    } catch (e) {
      print('Error getting nearby sightings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> confirmAuroraSighting(String sightingId) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      final sightingRef = firestore.collection('aurora_sightings').doc(sightingId);
      
      return await firestore.runTransaction((transaction) async {
        final sightingDoc = await transaction.get(sightingRef);
        if (!sightingDoc.exists) {
          throw Exception('Sighting not found');
        }

        final data = sightingDoc.data() as Map<String, dynamic>;
        final verifications = List<String>.from(data['verifications'] ?? []);
        final isLiked = verifications.contains(user.uid);

        if (isLiked) {
          verifications.remove(user.uid);
        } else {
          verifications.add(user.uid);
        }

        final confirmations = verifications.length;

        // Update the document with all necessary fields
        transaction.update(sightingRef, {
          'verifications': verifications,
          'confirmations': confirmations,
          'isVerified': confirmations >= 3,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Also update the user's verification count
        if (isAuthenticated) {
          transaction.update(
            firestore.collection('users').doc(user.uid),
            {
              'verificationCount': FieldValue.increment(isLiked ? -1 : 1),
              'lastActive': FieldValue.serverTimestamp(),
            },
          );
        }

        return {
          'isLiked': !isLiked,
          'confirmations': confirmations,
        };
      });
    } catch (e) {
      print('Error confirming sighting: $e');
      rethrow;
    }
  }

  Future<List<AuroraSighting>> getRecentSightings() async {
    try {
      final now = DateTime.now();
      final twelveHoursAgo = now.subtract(const Duration(hours: 12));

      final snapshot = await firestore
          .collection('aurora_sightings')
          .where('timestamp', isGreaterThan: twelveHoursAgo)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => AuroraSighting.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting recent sightings: $e');
      return [];
    }
  }

  Future<String> uploadBannerImage(File imageFile) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final storageRef = storage.ref().child('banner_images/${user.uid}');
    final uploadTask = storageRef.putFile(imageFile);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}