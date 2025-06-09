// lib/widgets/sighting_card.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/aurora_sighting.dart';

class SightingCard extends StatelessWidget {
  final AuroraSighting sighting;
  final Position? currentLocation;
  final VoidCallback onTap;
  final VoidCallback onConfirm;

  const SightingCard({
    super.key,
    required this.sighting,
    this.currentLocation,
    required this.onTap,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getIntensityColor(sighting.intensity).withOpacity(0.1),
            Colors.black.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getIntensityColor(sighting.intensity).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Intensity indicator
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getIntensityColor(sighting.intensity).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getIntensityColor(sighting.intensity),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          sighting.intensity.toString(),
                          style: TextStyle(
                            color: _getIntensityColor(sighting.intensity),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Sighting info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${sighting.intensityDescription} Aurora',
                                style: TextStyle(
                                  color: _getIntensityColor(sighting.intensity),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (sighting.isVerified) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.verified,
                                  color: Colors.tealAccent,
                                  size: 16,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'by ${sighting.userName}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Time and freshness indicator
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          sighting.timeAgo,
                          style: TextStyle(
                            color: sighting.isFresh ? Colors.tealAccent : Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (sighting.isFresh)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.tealAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'FRESH',
                              style: TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Location and distance
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Tooltip(
                        message: sighting.locationName,
                        child: Text(
                          sighting.locationName.length > 24
                              ? sighting.locationName.substring(0, 24) + '...'
                              : sighting.locationName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    if (currentLocation != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${_calculateDistance().toStringAsFixed(1)} km away',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),

                // Description (if available)
                if (sighting.description != null && sighting.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    sighting.description!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Photos preview and actions
                Row(
                  children: [
                    // Photos indicator
                    if (sighting.photoUrls.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.photo,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${sighting.photoUrls.length}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const Spacer(),

                    // Confirm button
                    GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.tealAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.tealAccent.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.thumb_up_outlined,
                              color: Colors.tealAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Confirm (${sighting.confirmations})',
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Weather conditions (if available)
                if (sighting.weather.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.thermostat,
                          color: Colors.white54,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'BzH: ${sighting.weather['bzH']?.toStringAsFixed(1) ?? 'N/A'} nT',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Kp: ${sighting.weather['kp']?.toStringAsFixed(1) ?? 'N/A'}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getIntensityColor(int intensity) {
    switch (intensity) {
      case 1: return Colors.blue[300]!;
      case 2: return Colors.green[400]!;
      case 3: return Colors.tealAccent;
      case 4: return Colors.orange[400]!;
      case 5: return Colors.amber;
      default: return Colors.grey;
    }
  }

  double _calculateDistance() {
    if (currentLocation == null) return 0.0;

    return Geolocator.distanceBetween(
      currentLocation!.latitude,
      currentLocation!.longitude,
      sighting.location.latitude,
      sighting.location.longitude,
    ) / 1000; // Convert to kilometers
  }
}