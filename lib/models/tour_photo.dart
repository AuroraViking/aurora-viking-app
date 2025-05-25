// lib/models/tour_photo.dart
class TourPhoto {
  final String id;
  final String fileName;
  final String tourName;
  final DateTime date;
  final String thumbnailUrl;
  final String downloadUrl;
  final String fileSize;

  TourPhoto({
    required this.id,
    required this.fileName,
    required this.tourName,
    required this.date,
    required this.thumbnailUrl,
    required this.downloadUrl,
    required this.fileSize,
  });

  /// Formatted date string for display
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Formatted date and time string
  String get formattedDateTime {
    return '${formattedDate} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Create TourPhoto from JSON (for API integration)
  factory TourPhoto.fromJson(Map<String, dynamic> json) {
    return TourPhoto(
      id: json['id'] ?? '',
      fileName: json['name'] ?? '',
      tourName: json['tourName'] ?? 'Aurora Tour',
      date: DateTime.tryParse(json['createdDate'] ?? '') ?? DateTime.now(),
      thumbnailUrl: json['thumbnailLink'] ?? '',
      downloadUrl: json['downloadLink'] ?? '',
      fileSize: _formatFileSize(json['size']),
    );
  }

  /// Convert TourPhoto to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': fileName,
      'tourName': tourName,
      'createdDate': date.toIso8601String(),
      'thumbnailLink': thumbnailUrl,
      'downloadLink': downloadUrl,
      'size': fileSize,
    };
  }

  /// Format file size from bytes to human readable
  static String _formatFileSize(dynamic sizeBytes) {
    if (sizeBytes == null) return 'Unknown size';

    try {
      final bytes = int.parse(sizeBytes.toString());
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } catch (e) {
      return sizeBytes.toString();
    }
  }

  @override
  String toString() {
    return 'TourPhoto(id: $id, fileName: $fileName, tourName: $tourName, date: $date)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TourPhoto && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}