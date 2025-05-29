class Tour {
  final String id;
  final String name;
  final DateTime date;
  final String location;
  final String description;
  final String bookingReference;
  final List<String> photoUrls;
  final Map<String, dynamic> bookingDetails;
  final bool isPast;

  Tour({
    required this.id,
    required this.name,
    required this.date,
    required this.location,
    required this.description,
    required this.bookingReference,
    this.photoUrls = const [],
    this.bookingDetails = const {},
    this.isPast = false,
  });

  factory Tour.fromJson(Map<String, dynamic> json) {
    return Tour(
      id: json['id'] as String,
      name: json['name'] as String,
      date: DateTime.parse(json['date'] as String),
      location: json['location'] as String,
      description: json['description'] as String,
      bookingReference: json['bookingReference'] as String,
      photoUrls: List<String>.from(json['photoUrls'] ?? []),
      bookingDetails: json['bookingDetails'] as Map<String, dynamic>? ?? {},
      isPast: json['isPast'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'location': location,
      'description': description,
      'bookingReference': bookingReference,
      'photoUrls': photoUrls,
      'bookingDetails': bookingDetails,
      'isPast': isPast,
    };
  }
} 