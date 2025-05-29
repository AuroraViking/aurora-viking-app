import 'package:flutter/material.dart';
import '../../models/tour.dart';

class TourInfoCard extends StatelessWidget {
  final Tour tour;
  final VoidCallback onViewPhotos;
  final VoidCallback onViewBooking;

  const TourInfoCard({
    super.key,
    required this.tour,
    required this.onViewPhotos,
    required this.onViewBooking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.tealAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tour Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                tour.photoUrls.isNotEmpty ? tour.photoUrls.first : 'https://via.placeholder.com/400x225',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(Icons.image, color: Colors.white54, size: 48),
                    ),
                  );
                },
              ),
            ),
          ),

          // Tour Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tour.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: tour.isPast ? Colors.grey : Colors.tealAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tour.isPast ? 'Past' : 'Upcoming',
                        style: TextStyle(
                          color: tour.isPast ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.tealAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      tour.location,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, color: Colors.tealAccent, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${tour.date.day}/${tour.date.month}/${tour.date.year}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  tour.description,
                  style: const TextStyle(color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: onViewPhotos,
                      icon: const Icon(Icons.photo_library, color: Colors.tealAccent),
                      label: const Text(
                        'View Photos',
                        style: TextStyle(color: Colors.tealAccent),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onViewBooking,
                      icon: const Icon(Icons.receipt_long, color: Colors.tealAccent),
                      label: const Text(
                        'Booking Details',
                        style: TextStyle(color: Colors.tealAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 