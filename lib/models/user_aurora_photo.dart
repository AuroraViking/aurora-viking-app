// lib/models/user_aurora_photo.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserAuroraPhoto {
  final String id;
  final String userId;
  final String userName;
  final String sightingId; // Link to the aurora sighting
  final String photoUrl;
  final String thumbnailUrl;
  final DateTime capturedAt;
  final String locationName;
  final int intensity;
  final bool isPublic;
  final bool isAvailableForPrint;
  final int printCount;
  final DateTime? lastPrintedAt;
  final Map<String, dynamic> metadata;

  UserAuroraPhoto({
    required this.id,
    required this.userId,
    required this.userName,
    required this.sightingId,
    required this.photoUrl,
    required this.thumbnailUrl,
    required this.capturedAt,
    required this.locationName,
    required this.intensity,
    required this.isPublic,
    required this.isAvailableForPrint,
    required this.printCount,
    this.lastPrintedAt,
    required this.metadata,
  });

  /// Create from Firestore document
  factory UserAuroraPhoto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAuroraPhoto(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Aurora Hunter',
      sightingId: data['sightingId'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? data['photoUrl'] ?? '',
      capturedAt: (data['capturedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      locationName: data['locationName'] ?? 'Unknown Location',
      intensity: data['intensity'] ?? 1,
      isPublic: data['isPublic'] ?? true,
      isAvailableForPrint: data['isAvailableForPrint'] ?? true,
      printCount: data['printCount'] ?? 0,
      lastPrintedAt: (data['lastPrintedAt'] as Timestamp?)?.toDate(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'sightingId': sightingId,
      'photoUrl': photoUrl,
      'thumbnailUrl': thumbnailUrl,
      'capturedAt': Timestamp.fromDate(capturedAt),
      'locationName': locationName,
      'intensity': intensity,
      'isPublic': isPublic,
      'isAvailableForPrint': isAvailableForPrint,
      'printCount': printCount,
      'lastPrintedAt': lastPrintedAt != null ? Timestamp.fromDate(lastPrintedAt!) : null,
      'metadata': metadata,
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

  /// Get formatted capture date
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(capturedAt);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${capturedAt.day} ${months[capturedAt.month - 1]} ${capturedAt.year}';
    }
  }

  /// Get formatted capture date and time
  String get formattedDateTime {
    return '${formattedDate} ${capturedAt.hour.toString().padLeft(2, '0')}:${capturedAt.minute.toString().padLeft(2, '0')}';
  }

  /// Check if photo was captured recently (within last hour)
  bool get isRecent => DateTime.now().difference(capturedAt).inHours < 1;

  /// Check if photo has been printed
  bool get hasBeenPrinted => printCount > 0;

  /// Get print status text
  String get printStatusText {
    if (printCount == 0) return 'Never printed';
    if (printCount == 1) return 'Printed once';
    return 'Printed $printCount times';
  }

  /// Get sharing status text
  String get sharingStatusText {
    if (isPublic) return 'Public';
    return 'Private';
  }

  /// Create a copy with updated values
  UserAuroraPhoto copyWith({
    String? id,
    String? userId,
    String? userName,
    String? sightingId,
    String? photoUrl,
    String? thumbnailUrl,
    DateTime? capturedAt,
    String? locationName,
    int? intensity,
    bool? isPublic,
    bool? isAvailableForPrint,
    int? printCount,
    DateTime? lastPrintedAt,
    Map<String, dynamic>? metadata,
  }) {
    return UserAuroraPhoto(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      sightingId: sightingId ?? this.sightingId,
      photoUrl: photoUrl ?? this.photoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      capturedAt: capturedAt ?? this.capturedAt,
      locationName: locationName ?? this.locationName,
      intensity: intensity ?? this.intensity,
      isPublic: isPublic ?? this.isPublic,
      isAvailableForPrint: isAvailableForPrint ?? this.isAvailableForPrint,
      printCount: printCount ?? this.printCount,
      lastPrintedAt: lastPrintedAt ?? this.lastPrintedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'UserAuroraPhoto(id: $id, user: $userName, intensity: $intensity, location: $locationName, date: $formattedDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserAuroraPhoto && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Print order item for user photos
class UserPhotosPrintItem {
  final String photoId;
  final UserAuroraPhoto photo;
  final String productType;
  final String variantId;
  final int quantity;
  final double price;

  UserPhotosPrintItem({
    required this.photoId,
    required this.photo,
    required this.productType,
    required this.variantId,
    required this.quantity,
    required this.price,
  });

  double get totalPrice => price * quantity;

  Map<String, dynamic> toJson() {
    return {
      'photoId': photoId,
      'productType': productType,
      'variantId': variantId,
      'quantity': quantity,
      'price': price,
      'photoUrl': photo.photoUrl,
      'locationName': photo.locationName,
      'intensity': photo.intensity,
      'capturedAt': photo.capturedAt.toIso8601String(),
    };
  }
}

/// Print package for multiple products from same photo
class UserPhotoPrintPackage {
  final UserAuroraPhoto photo;
  final List<UserPhotosPrintItem> items;
  final DateTime createdAt;

  UserPhotoPrintPackage({
    required this.photo,
    required this.items,
    required this.createdAt,
  });

  double get totalPrice => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toJson() {
    return {
      'photoId': photo.id,
      'items': items.map((item) => item.toJson()).toList(),
      'totalPrice': totalPrice,
      'totalItems': totalItems,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}