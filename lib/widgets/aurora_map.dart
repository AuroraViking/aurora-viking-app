// lib/widgets/aurora_map.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../models/aurora_sighting.dart';
import '../services/cloud_tile_provider.dart';
import '../services/config_service.dart';

class AuroraMap extends StatefulWidget {
  final Position currentLocation;
  final List<AuroraSighting> sightings;
  final Function(GoogleMapController) onMapCreated;
  final Function(AuroraSighting)? onSightingTapped;

  const AuroraMap({
    super.key,
    required this.currentLocation,
    required this.sightings,
    required this.onMapCreated,
    this.onSightingTapped,
  });

  @override
  State<AuroraMap> createState() => _AuroraMapState();
}

class _AuroraMapState extends State<AuroraMap> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  Set<TileOverlay> _tileOverlays = {};

  @override
  void initState() {
    super.initState();
    _createMarkers();
    _createTileOverlays();
  }

  @override
  void didUpdateWidget(AuroraMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sightings != widget.sightings) {
      _createMarkers();
    }
  }

  void _createMarkers() {
    final markers = <Marker>{};
    final circles = <Circle>{};

    // Add current location marker
    markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(
          widget.currentLocation.latitude,
          widget.currentLocation.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'You are here',
        ),
      ),
    );

    // Add sighting markers
    for (int i = 0; i < widget.sightings.length; i++) {
      final sighting = widget.sightings[i];
      final position = LatLng(
        sighting.location.latitude,
        sighting.location.longitude,
      );

      // Create marker
      markers.add(
        Marker(
          markerId: MarkerId('sighting_${sighting.id}'),
          position: position,
          icon: _getMarkerIcon(sighting.intensity),
          infoWindow: InfoWindow(
            title: '${sighting.intensityDescription} Aurora',
            snippet: '${sighting.userName} • ${sighting.timeAgo}',
          ),
          onTap: () => widget.onSightingTapped?.call(sighting),
        ),
      );

      // Add circle for active sightings
      if (sighting.isActive) {
        circles.add(
          Circle(
            circleId: CircleId('circle_${sighting.id}'),
            center: position,
            radius: _getRadiusForIntensity(sighting.intensity),
            fillColor: _getIntensityColor(sighting.intensity).withOpacity(0.1),
            strokeColor: _getIntensityColor(sighting.intensity).withOpacity(0.3),
            strokeWidth: 2,
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
      _circles = circles;
    });
  }

  void _createTileOverlays() {
    final TileOverlay cloudOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('cloud_overlay'),
      tileProvider: CloudTileProvider(
        urlTemplate: 'https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid=[36m${ConfigService.weatherApiKey}[0m',
        timeOffset: 0,
      ),
      transparency: 0.05,
    );

    setState(() {
      _tileOverlays = {cloudOverlay};
    });
  }

  BitmapDescriptor _getMarkerIcon(int intensity) {
    // For now, use default markers with different colors
    // In production, you'd create custom marker icons
    switch (intensity) {
      case 1:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case 2:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      case 3:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
      case 4:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      case 5:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
      default:
        return BitmapDescriptor.defaultMarker;
    }
  }

  double _getRadiusForIntensity(int intensity) {
    switch (intensity) {
      case 1: return 5000; // 5km
      case 2: return 10000; // 10km
      case 3: return 15000; // 15km
      case 4: return 25000; // 25km
      case 5: return 50000; // 50km
      default: return 10000;
    }
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // Set dark theme for the map
    controller.setMapStyle('''
    [
      {
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#1d2c4d"
          }
        ]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [
          {
            "color": "#8ec3b9"
          }
        ]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [
          {
            "color": "#1a3646"
          }
        ]
      },
      {
        "featureType": "administrative.country",
        "elementType": "geometry.stroke",
        "stylers": [
          {
            "color": "#4b6878"
          }
        ]
      },
      {
        "featureType": "landscape.man_made",
        "elementType": "geometry.stroke",
        "stylers": [
          {
            "color": "#334e87"
          }
        ]
      },
      {
        "featureType": "poi",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#283d6a"
          }
        ]
      },
      {
        "featureType": "road",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#304a7d"
          }
        ]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [
          {
            "color": "#0e1626"
          }
        ]
      }
    ]
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: LatLng(
              widget.currentLocation.latitude,
              widget.currentLocation.longitude,
            ),
            zoom: 8.0,
          ),
          markers: _markers,
          circles: _circles,
          tileOverlays: _tileOverlays,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          compassEnabled: true,
          mapType: MapType.normal,
        ),

        // Legend overlay
        Positioned(
          top: 16,
          left: 16,
          child: _buildLegend(),
        ),

        // Controls
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            children: [
              // Zoom to current location
              FloatingActionButton(
                heroTag: "zoom_to_location",
                mini: true,
                backgroundColor: Colors.tealAccent,
                foregroundColor: Colors.black,
                onPressed: _zoomToCurrentLocation,
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 8),
              // Zoom to fit all sightings
              FloatingActionButton(
                heroTag: "zoom_to_fit",
                mini: true,
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.tealAccent,
                onPressed: _zoomToFitAllSightings,
                child: const Icon(Icons.zoom_out_map),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.tealAccent,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'Aurora Intensity',
                style: TextStyle(
                  color: Colors.tealAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(5, (index) {
            final intensity = index + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getIntensityColor(intensity),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$intensity - ${_getIntensityName(intensity)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _getIntensityName(int intensity) {
    switch (intensity) {
      case 1: return 'Faint';
      case 2: return 'Weak';
      case 3: return 'Moderate';
      case 4: return 'Strong';
      case 5: return 'Exceptional';
      default: return 'Unknown';
    }
  }

  void _zoomToCurrentLocation() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              widget.currentLocation.latitude,
              widget.currentLocation.longitude,
            ),
            zoom: 12.0,
          ),
        ),
      );
    }
  }

  void _zoomToFitAllSightings() {
    if (_mapController != null && widget.sightings.isNotEmpty) {
      final bounds = _calculateBounds();
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }

  LatLngBounds _calculateBounds() {
    double minLat = widget.currentLocation.latitude;
    double maxLat = widget.currentLocation.latitude;
    double minLng = widget.currentLocation.longitude;
    double maxLng = widget.currentLocation.longitude;

    for (final sighting in widget.sightings) {
      minLat = minLat < sighting.location.latitude ? minLat : sighting.location.latitude;
      maxLat = maxLat > sighting.location.latitude ? maxLat : sighting.location.latitude;
      minLng = minLng < sighting.location.longitude ? minLng : sighting.location.longitude;
      maxLng = maxLng > sighting.location.longitude ? maxLng : sighting.location.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}