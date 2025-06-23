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
import 'package:geolocator/geolocator.dart';
import '../services/notification_service.dart';

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
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (e) {
      // Handle sign out error
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user) async {
    try {
      final userData = {
        'email': user.email,
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'auroraSpottingCount': 0,
        'verificationCount': 0,
        'lastActive': FieldValue.serverTimestamp(),
        'userType': 'aurora_user',
        'tourParticipant': false,
        'tourBookings': [],
        'verifiedTourEmail': null,
        'profilePictureUrl': null,
        'bio': null,
        'location': null,
        'lastLocationName': null,
      };

      await firestore.collection('users').doc(user.uid).set(userData, SetOptions(merge: true));
    } catch (e) {
      // Handle user profile creation error
    }
  }

  // TOUR VERIFICATION METHODS

  // Verify tour participant by email (for compatibility with your existing screen)
  Future<Map<String, dynamic>?> verifyTourParticipant(String email) async {
    try {
      // First check if we have any verified bookings in Firestore that match this email
      final verifiedBookings = await _checkFirestoreForVerifiedBooking(email);
      if (verifiedBookings != null) {
        return verifiedBookings;
      }

      // If not found in Firestore, try to find in Bokun by searching all bookings
      // Note: This is a fallback - in real implementation you'd have email-to-booking mapping

      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Verify tour participant by booking reference
  Future<Map<String, dynamic>?> verifyTourParticipantByReference(String reference) async {
    try {
      // First verify the booking exists in Bokun
      final bookingDetails = await BokunService.verifyBookingReference(reference);

      if (bookingDetails != null && bookingDetails['isValid'] == true) {
        // Store the verification in Firestore
        await _storeVerifiedBookingByReference(reference, bookingDetails);
        return bookingDetails;
      }

      return null;
    } catch (e) {
      rethrow;
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
        return data;
      }
    } catch (e) {
      // Handle error checking Firestore
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
    } catch (e) {
      // Handle error storing verified booking
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
    } catch (e) {
      // Handle error storing verified booking by reference
    }
  }

  // Get user type
  Future<String> getUserType() async {
    if (currentUser == null) return 'guest';

    try {
      final doc = await firestore.collection('users').doc(currentUser!.uid).get();
      return doc.data()?['userType'] ?? 'aurora_user';
    } catch (e) {
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
        if (photoUrl == null) {
          throw Exception('Photo upload failed');
        }
      }

      // Get user's display name from their profile
      final userDoc = await firestore.collection('users').doc(currentUser!.uid).get();
      String userDisplayName;
      
      if (userDoc.exists) {
        // Try to get display name from user profile
        userDisplayName = userDoc.data()?['displayName'] ?? 
                         userDoc.data()?['userName'] ?? 
                         currentUser!.displayName ?? 
                         currentUser!.email?.split('@')[0] ?? 
                         'Aurora Hunter';
      } else {
        // Create user profile if it doesn't exist
        userDisplayName = currentUser!.displayName ?? 
                         currentUser!.email?.split('@')[0] ?? 
                         'Aurora Hunter';
        
        // Create user profile
        await firestore.collection('users').doc(currentUser!.uid).set({
          'displayName': userDisplayName,
          'email': currentUser!.email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
          'auroraSpottingCount': 0,
          'verificationCount': 0,
        });
      }

      // Create sighting document
      final sightingRef = await firestore.collection('aurora_sightings').add({
        'userId': currentUser!.uid,
        'userName': userDisplayName,
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
          latitude: latitude,
          longitude: longitude,
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
      rethrow;
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
    int hours = 24,
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
      final data = doc.data();
      final location = data['location'];
      
      // Handle both GeoPoint and Map locations
      double sightingLat, sightingLng;
      if (location is GeoPoint) {
        sightingLat = location.latitude;
        sightingLng = location.longitude;
      } else if (location is Map<String, dynamic>) {
        sightingLat = location['latitude']?.toDouble() ?? 0.0;
        sightingLng = location['longitude']?.toDouble() ?? 0.0;
      } else {
        return false; // Skip invalid locations
      }

      final distance = _calculateDistance(
        latitude, longitude,
        sightingLat, sightingLng,
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
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
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
      // Permission granted
    }

    // Get FCM token
    final token = await messaging.getToken();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle the message (show local notification)
    });
  }

  // Subscribe to aurora alerts for location
  Future<void> subscribeToAuroraAlerts(String locationKey) async {
    await messaging.subscribeToTopic('aurora_alerts_$locationKey');
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
      return const Stream.empty();
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
    } catch (e) {
      // Handle user type update error
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

      // Add the comment and update the sighting's comment count in a transaction
      await firestore.runTransaction((transaction) async {
        // Add the comment
        transaction.set(
          firestore
              .collection('aurora_sightings')
              .doc(sightingId)
              .collection('comments')
              .doc(comment.id),
          comment.toFirestore(),
        );

        // Update the sighting's comment count
        final sightingRef = firestore.collection('aurora_sightings').doc(sightingId);
        transaction.update(sightingRef, {
          'commentCount': FieldValue.increment(1),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AuroraSighting>> getNearbySightings() async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user's location from their last sighting or profile
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final userLocation = userDoc.data()?['location'];

      double latitude, longitude;

      if (userLocation == null) {
        // If no location in profile, try to get from last sighting
        final lastSighting = await firestore
            .collection('aurora_sightings')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (lastSighting.docs.isEmpty) {
          // If no last sighting, get current device location
          try {
            final position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 10),
            );
            latitude = position.latitude;
            longitude = position.longitude;
            
            // Update user's profile with current location
            await firestore.collection('users').doc(user.uid).update({
              'location': GeoPoint(latitude, longitude),
              'lastLocationUpdate': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            return [];
          }
        } else {
          final sightingData = lastSighting.docs.first.data();
          final location = sightingData['location'];

          if (location is GeoPoint) {
            latitude = location.latitude;
            longitude = location.longitude;
          } else if (location is Map<String, dynamic>) {
            latitude = location['latitude']?.toDouble() ?? 0.0;
            longitude = location['longitude']?.toDouble() ?? 0.0;
          } else {
            return [];
          }
        }
      } else {
        if (userLocation is GeoPoint) {
          latitude = userLocation.latitude;
          longitude = userLocation.longitude;
        } else if (userLocation is Map<String, dynamic>) {
          latitude = userLocation['latitude']?.toDouble() ?? 0.0;
          longitude = userLocation['longitude']?.toDouble() ?? 0.0;
        } else {
          return [];
        }
      }

      // Get all recent sightings and filter by distance
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));
      
      final snapshot = await firestore
          .collection('aurora_sightings')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(twentyFourHoursAgo))
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final sightings = snapshot.docs
          .map((doc) => AuroraSighting.fromFirestore(doc))
          .where((sighting) {
            final distance = _calculateDistance(
              latitude, longitude,
              sighting.location.latitude, sighting.location.longitude,
            );
            final isNearby = distance <= 100; // 100km radius
            return isNearby;
          })
          .toList();

      return sightings;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> confirmAuroraSighting(String sightingId) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

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
          final userRef = firestore.collection('users').doc(user.uid);
          transaction.update(userRef, {
            'verificationCount': FieldValue.increment(isLiked ? -1 : 1),
            'lastActive': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }

        final result = {
          'isLiked': !isLiked,
          'confirmations': confirmations,
          'verifications': verifications,
        };
        return result;
      });
    } catch (e) {
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

  Future<void> addAuroraSighting(AuroraSighting sighting) async {
    try {
      final docRef = await firestore.collection('aurora_sightings').add(sighting.toFirestore());
      sighting.id = docRef.id;
      
      // Cloud Function will automatically handle notifications
      // No need to call local notification service here
    } catch (e) {
      throw Exception('Failed to add aurora sighting: $e');
    }
  }

  // NOTIFICATION METHODS

  // Check if should show nearby alert
  Future<bool> shouldShowNearbyAlert() async {
    try {
      // For now, return true if user has recent sightings nearby
      final nearbySightings = await getNearbySightings();
      return nearbySightings.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Check if should show high activity alert
  Future<bool> shouldShowHighActivityAlert() async {
    try {
      final recentSightings = await getRecentSightings();
      final highIntensitySightings = recentSightings.where((s) => s.intensity >= 4).length;
      return highIntensitySightings >= 3; // Show alert if 3+ high intensity sightings
    } catch (e) {
      return false;
    }
  }

  // Get user notification settings
  Future<Map<String, dynamic>> getUserNotificationSettings() async {
    if (currentUser == null) {
      return {
        'appUpdates': true,
        'highActivityAlert': true,
        'alertNearby': true,
        'spaceWeatherAlert': true,
      };
    }

    try {
      final doc = await firestore.collection('users').doc(currentUser!.uid).get();
      final data = doc.data() ?? {};
      
      return {
        'appUpdates': data['notificationSettings']?['appUpdates'] ?? true,
        'highActivityAlert': data['notificationSettings']?['highActivityAlert'] ?? true,
        'alertNearby': data['notificationSettings']?['alertNearby'] ?? true,
        'spaceWeatherAlert': data['notificationSettings']?['spaceWeatherAlert'] ?? true,
      };
    } catch (e) {
      return {
        'appUpdates': true,
        'highActivityAlert': true,
        'alertNearby': true,
        'spaceWeatherAlert': true,
      };
    }
  }

  // Set user notification settings
  Future<void> setUserNotificationSettings(Map<String, dynamic> settings) async {
    if (currentUser == null) return;

    try {
      await firestore.collection('users').doc(currentUser!.uid).update({
        'notificationSettings': settings,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update notification settings');
    }
  }

  // Clear block cache for a user (call after unblocking)
  Future<void> clearBlockCache(String userId) async {
    try {
      // Force a fresh read from Firestore by getting the document
      await firestore.collection('blocked_users').doc(userId).get();
    } catch (e) {
      // Handle error clearing block cache
    }
  }

  // Check for high activity and trigger notifications
  Future<void> checkAndNotifyHighActivity() async {
    try {
      final recentSightings = await getRecentSightings();
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      
      // Count sightings in the last hour
      final recentCount = recentSightings.where((s) => s.timestamp.isAfter(oneHourAgo)).length;
      
      if (recentCount >= 5) { // Trigger if 5+ sightings in last hour
        // Get the most common location
        final locationCounts = <String, int>{};
        for (final sighting in recentSightings.where((s) => s.timestamp.isAfter(oneHourAgo))) {
          locationCounts[sighting.locationName] = (locationCounts[sighting.locationName] ?? 0) + 1;
        }
        
        final mostCommonLocation = locationCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        
        await NotificationService.notifyHighActivity(
          sightingCount: recentCount,
          location: mostCommonLocation,
        );
      }
    } catch (e) {
      // Handle error checking high activity
    }
  }
}