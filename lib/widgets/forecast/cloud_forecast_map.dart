import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import '../../services/cloud_forecast_service.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class CloudForecastMap extends StatefulWidget {
  final Position position;

  const CloudForecastMap({
    super.key,
    required this.position,
  });

  @override
  State<CloudForecastMap> createState() => _CloudForecastMapState();
}

class _CloudForecastMapState extends State<CloudForecastMap> {
  final CloudForecastService _forecastService = CloudForecastService();
  GoogleMapController? _mapController;
  bool _isMapLoading = true;
  bool _isLoadingForecast = false;
  LatLng _currentCenter = LatLng(0, 0);
  Set<Polygon> _cloudPolygons = {};
  double _timeOffset = 0;
  Map<String, dynamic>? _forecastData;
  List<Map<String, dynamic>>? _forecastPoints;
  double _currentZoom = 7;
  LatLngBounds? _visibleBounds;

  @override
  void initState() {
    super.initState();
    print('CloudForecastMap: initState, widget.position = \\${widget.position}');
    // Print API key if available from env
    const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: 'NOT_SET');
    print('CloudForecastMap: GOOGLE_MAPS_API_KEY (from env): $apiKey');
    // Print package name
    PackageInfo.fromPlatform().then((info) {
      print('CloudForecastMap: packageName = \\${info.packageName}');
    });
    _currentCenter = LatLng(widget.position.latitude, widget.position.longitude);
    _currentZoom = 7;
  }

  Future<void> _loadForecast() async {
    if (_isLoadingForecast) return;
    print('CloudForecastMap: _loadForecast called');
    setState(() {
      _isLoadingForecast = true;
    });

    try {
      if (_mapController == null) {
        print('CloudForecastMap: _mapController is null, aborting _loadForecast');
        return;
      }

      // Get the visible bounds
      final bounds = await _mapController!.getVisibleRegion();
      print('CloudForecastMap: visible bounds = \\${bounds.toString()}');
      _visibleBounds = bounds;
      
      // Calculate grid points based on visible bounds
      final gridPoints = _calculateGridPoints(bounds);
      print('CloudForecastMap: gridPoints count = \\${gridPoints.length}');
      
      // Get forecasts for all grid points
      final forecasts = await _forecastService.getCloudForecastForPoints(gridPoints);
      print('CloudForecastMap: forecasts loaded, count = \\${forecasts.length}');
      
      if (mounted) {
        setState(() {
          _forecastPoints = forecasts;
          _updateCloudPolygons();
        });
      }
    } on TimeoutException catch (e) {
      print('CloudForecastMap: Timeout loading forecast: \\${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading forecast timed out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('CloudForecastMap: Error loading forecast: \\${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading forecast: \\${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingForecast = false;
        });
      }
    }
  }

  List<Map<String, double>> _calculateGridPoints(LatLngBounds bounds) {
    const gridRows = 20;
    const gridCols = 20;
    final points = <Map<String, double>>[];
    
    // Calculate the size of each grid cell
    final latStep = (bounds.northeast.latitude - bounds.southwest.latitude) / gridRows;
    final lngStep = (bounds.northeast.longitude - bounds.southwest.longitude) / gridCols;
    
    // Generate points for the center of each grid cell
    for (int row = 0; row < gridRows; row++) {
      for (int col = 0; col < gridCols; col++) {
        final lat = bounds.southwest.latitude + (latStep * (row + 0.5));
        final lng = bounds.southwest.longitude + (lngStep * (col + 0.5));
        
        points.add({
          'lat': lat,
          'lng': lng,
          'row': row.toDouble(),
          'col': col.toDouble(),
        });
      }
    }
    
    return points;
  }

  void _updateCloudPolygons() {
    if (_forecastPoints == null || _visibleBounds == null) {
      print('CloudForecastMap: Missing forecast data or bounds in _updateCloudPolygons');
      return;
    }

    final polygons = <Polygon>{};
    const gridRows = 20;
    const gridCols = 20;
    
    // Calculate the size of each grid cell
    final latStep = (_visibleBounds!.northeast.latitude - _visibleBounds!.southwest.latitude) / gridRows;
    final lngStep = (_visibleBounds!.northeast.longitude - _visibleBounds!.southwest.longitude) / gridCols;
    
    // Create a polygon for each grid cell
    for (int i = 0; i < _forecastPoints!.length; i++) {
      final forecast = _forecastPoints![i];
      final hourly = forecast['hourly'] as Map<String, dynamic>;
      final times = hourly['time'] as List<dynamic>;
      final cloudCover = hourly['cloudcover'] as List<dynamic>;
      
      // Find the closest time index
      final now = DateTime.now();
      final targetTime = now.add(Duration(hours: _timeOffset.toInt()));
      int closestIndex = 0;
      double minDiff = double.infinity;
      
      for (int j = 0; j < times.length; j++) {
        final time = DateTime.parse(times[j]);
        final diff = (time.difference(targetTime)).abs().inMinutes;
        if (diff < minDiff) {
          minDiff = diff.toDouble();
          closestIndex = j;
        }
      }
      
      final cloudValue = (cloudCover[closestIndex] as num).toDouble();
      final row = forecast['row'] as double;
      final col = forecast['col'] as double;
      
      // Calculate the corners of the grid cell
      final swLat = _visibleBounds!.southwest.latitude + (latStep * row);
      final swLng = _visibleBounds!.southwest.longitude + (lngStep * col);
      final neLat = swLat + latStep;
      final neLng = swLng + lngStep;
      
      // Create the polygon points (clockwise from southwest)
      final points = [
        LatLng(swLat, swLng), // Southwest
        LatLng(swLat, neLng), // Southeast
        LatLng(neLat, neLng), // Northeast
        LatLng(neLat, swLng), // Northwest
      ];
      
      polygons.add(
        Polygon(
          polygonId: PolygonId('cloud_${row}_${col}'),
          points: points,
          fillColor: Colors.white.withOpacity(cloudValue / 100 * 0.7), // Reduced opacity to show terrain
          strokeColor: Colors.transparent,
        ),
      );
    }
    
    print('CloudForecastMap: Created \\${polygons.length} polygons');
    
    if (mounted) {
      setState(() {
        _cloudPolygons = polygons;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('CloudForecastMap: build called, _currentCenter = \\${_currentCenter}, _currentZoom = \\${_currentZoom}, myLocationEnabled: true, polygons: \\${_cloudPolygons.length}');
    final screenHeight = MediaQuery.of(context).size.height;
    final mapHeight = screenHeight * 0.6; // Reduced from 0.7 to 0.6 to prevent overflow
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.tealAccent.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'After panning to a new location, the app will generate a custom cloud cover forecast for that area. This process may take up to 60 seconds. The forecast will update automatically when you stop moving the map.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: mapHeight,
          margin: const EdgeInsets.only(bottom: 0), // Remove bottom margin to prevent overflow
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            border: Border.all(
              color: Colors.tealAccent.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentCenter,
                    zoom: _currentZoom,
                  ),
                  onMapCreated: (controller) {
                    print('CloudForecastMap: GoogleMap onMapCreated called');
                    setState(() {
                      _mapController = controller;
                      _isMapLoading = false;
                    });
                    _loadForecast(); // Move here
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                  mapType: MapType.terrain,
                  polygons: _cloudPolygons,
                  onCameraMove: (position) {
                    print('CloudForecastMap: onCameraMove, position = \\${position.target}, zoom = \\${position.zoom}');
                    setState(() {
                      _currentCenter = position.target;
                      _currentZoom = position.zoom;
                    });
                  },
                  onCameraIdle: () {
                    print('CloudForecastMap: onCameraIdle');
                    _loadForecast();
                  },
                ),
              ),
              if (_isMapLoading || _isLoadingForecast)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.tealAccent,
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Loading forecast data...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 0, // Move to very bottom to prevent overflow
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.tealAccent.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _getTimeLabel(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTimeLabels(),
                      const SizedBox(height: 4),
                      Stack(
                        children: [
                          SizedBox(
                            height: 20,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(49, (index) {
                                return Container(
                                  width: 1,
                                  height: 8,
                                  color: Colors.tealAccent.withOpacity(0.5),
                                );
                              }),
                            ),
                          ),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.tealAccent,
                              inactiveTrackColor: Colors.tealAccent.withOpacity(0.3),
                              thumbColor: Colors.tealAccent,
                              overlayColor: Colors.tealAccent.withOpacity(0.2),
                              valueIndicatorColor: Colors.tealAccent,
                              valueIndicatorTextStyle: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
                              trackHeight: 4,
                              activeTickMarkColor: Colors.tealAccent,
                              inactiveTickMarkColor: Colors.tealAccent.withOpacity(0.3),
                              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
                            ),
                            child: Slider(
                              value: _timeOffset,
                              min: 0,
                              max: 96,
                              divisions: 96,
                              label: _getTimeLabel(),
                              onChanged: _updateTimeOffset,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getTimeLabel() {
    final now = DateTime.now();
    final time = now.add(Duration(hours: _timeOffset.toInt()));
    return DateFormat('EEEE, MMM d, HH:mm').format(time);
  }

  Widget _buildTimeLabels() {
    final now = DateTime.now();
    final labels = <Widget>[];
    
    // Add labels for each day
    for (int i = 0; i <= 96; i += 24) {
      final time = now.add(Duration(hours: i));
      labels.add(
        SizedBox(
          width: 40,
          child: Column(
            children: [
              Container(
                width: 2,
                height: 8,
                color: Colors.tealAccent,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEE\nMMM d').format(time),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels,
    );
  }

  Future<void> _updateTimeOffset(double value) async {
    if (_forecastPoints == null) {
      // print('Cannot update time offset: missing forecast data');
      return;
    }

    setState(() {
      _timeOffset = value;
      _isLoadingForecast = true;
    });

    _updateCloudPolygons();

    // Add a small delay to ensure the loading indicator is visible
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      setState(() {
        _isLoadingForecast = false;
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}