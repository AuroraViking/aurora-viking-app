// lib/models/aurora_sighting.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AuroraSighting {
  final String id;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final GeoPoint location;
  final String locationName;
  final int intensity; // 1-5 scale
  final String? description;
  final List<String> photoUrls;
  final int confirmations;
  final List<String> confirmedByUsers;
  final bool isVerified;
  final Map<String, dynamic> weather;

  AuroraSighting({
    required this.id,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.location,
    required this.locationName,
    required this.intensity,
    this.description,
    required this.photoUrls,
    required this.confirmations,
    required this.confirmedByUsers,
    required this.isVerified,
    required this.weather,
  });

  /// Create from Firestore document
  factory AuroraSighting.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle location data - could be GeoPoint or Map
    GeoPoint location;
    if (data['location'] is GeoPoint) {
      location = data['location'] as GeoPoint;
    } else if (data['location'] is Map<String, dynamic>) {
      final locationMap = data['location'] as Map<String, dynamic>;
      location = GeoPoint(
        locationMap['latitude']?.toDouble() ?? 0.0,
        locationMap['longitude']?.toDouble() ?? 0.0,
      );
    } else {
      location = const GeoPoint(0.0, 0.0);
    }

    // Handle timestamp
    DateTime timestamp;
    if (data['timestamp'] is Timestamp) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else {
      timestamp = DateTime.now();
    }

    // Handle photo URLs - could be single URL or list
    List<String> photoUrls = [];
    if (data['photoUrl'] != null) {
      photoUrls = [data['photoUrl'] as String];
    } else if (data['photoUrls'] != null) {
      photoUrls = List<String>.from(data['photoUrls']);
    }

    // Handle verifications
    final verifications = List<String>.from(data['verifications'] ?? []);
    final confirmations = verifications.length;

    return AuroraSighting(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? data['userDisplayName'] ?? 'Anonymous',
      timestamp: timestamp,
      location: location,
      locationName: data['locationName'] ?? data['address'] ?? 'Unknown Location',
      intensity: data['intensity'] ?? 1,
      description: data['description'],
      photoUrls: photoUrls,
      confirmations: confirmations,
      confirmedByUsers: verifications,
      isVerified: data['isVerified'] ?? false,
      weather: Map<String, dynamic>.from(data['weather'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'timestamp': Timestamp.fromDate(timestamp),
      'location': location,
      'locationName': locationName,
      'intensity': intensity,
      'description': description,
      'photoUrls': photoUrls,
      'confirmations': confirmations,
      'confirmedByUsers': confirmedByUsers,
      'isVerified': isVerified,
      'weather': weather,
    };
  }

  /// Get intensity description
  String get intensityDescription {
    switch (intensity) {
      case 1: return 'Faint';
      case 2: return 'Weak';
      case 3: return 'Moderate';
      case 4: return 'Strong';
      case 5: return 'Exceptional';
      default: return 'Unknown';
    }
  }

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  /// Check if sighting is fresh (within last hour)
  bool get isFresh => DateTime.now().difference(timestamp).inHours < 1;

  /// Check if sighting is active (within last 3 hours)
  bool get isActive => DateTime.now().difference(timestamp).inHours < 3;

  /// Get formatted location coordinates
  String get formattedCoordinates {
    return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
  }

  /// Create a copy with updated confirmations
  AuroraSighting copyWith({
    int? confirmations,
    List<String>? confirmedByUsers,
    bool? isVerified,
  }) {
    return AuroraSighting(
      id: id,
      userId: userId,
      userName: userName,
      timestamp: timestamp,
      location: location,
      locationName: locationName,
      intensity: intensity,
      description: description,
      photoUrls: photoUrls,
      confirmations: confirmations ?? this.confirmations,
      confirmedByUsers: confirmedByUsers ?? this.confirmedByUsers,
      isVerified: isVerified ?? this.isVerified,
      weather: weather,
    );
  }

  @override
  String toString() {
    return 'AuroraSighting(id: $id, user: $userName, intensity: $intensity, location: $locationName, time: $timeAgo)';
  }
}

/// Alert types for aurora notifications
enum AlertType {
  firstSighting,
  confirmation,
  intensityIncrease,
  intensityDecrease,
  nearbyActivity,
}

class AuroraAlert {
  final String id;
  final String sightingId;
  final AlertType type;
  final GeoPoint location;
  final double radiusKm;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final String message;
  final Map<String, dynamic> metadata;

  AuroraAlert({
    required this.id,
    required this.sightingId,
    required this.type,
    required this.location,
    required this.radiusKm,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    required this.message,
    required this.metadata,
  });

  /// Create from Firestore document
  factory AuroraAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuroraAlert(
      id: doc.id,
      sightingId: data['sightingId'] ?? '',
      type: AlertType.values[data['type'] ?? 0],
      location: data['location'] as GeoPoint,
      radiusKm: (data['radiusKm'] ?? 50.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      message: data['message'] ?? '',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'sightingId': sightingId,
      'type': type.index,
      'location': location,
      'radiusKm': radiusKm,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'isActive': isActive,
      'message': message,
      'metadata': metadata,
    };
  }

  /// Check if alert is still valid
  bool get isValid => isActive && DateTime.now().isBefore(expiresAt);

  /// Get alert priority (1-5, 5 being highest)
  int get priority {
    switch (type) {
      case AlertType.firstSighting: return 4;
      case AlertType.confirmation: return 2;
      case AlertType.intensityIncrease: return 5;
      case AlertType.intensityDecrease: return 1;
      case AlertType.nearbyActivity: return 3;
    }
  }
}