import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/cloud_tile_provider.dart';

class CloudCoverMap extends StatefulWidget {
  final Position position;
  final double cloudCover;
  final String weatherDescription;
  final String weatherIcon;

  const CloudCoverMap({
    super.key,
    required this.position,
    required this.cloudCover,
    required this.weatherDescription,
    required this.weatherIcon,
  });

  @override
  State<CloudCoverMap> createState() => _CloudCoverMapState();
}

class _CloudCoverMapState extends State<CloudCoverMap> {
  GoogleMapController? _mapController;
  bool _isMapLoading = true;
  Set<TileOverlay> _tileOverlays = {};
  double _timeOffset = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _createTileOverlays();
  }

  void _createTileOverlays() {
    final TileOverlay cloudOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('cloud_overlay'),
      tileProvider: CloudTileProvider(
        urlTemplate: 'https://tile.openweathermap.org/map/clouds_new/{z}/{x}/{y}.png?appid=b7889cba97489be6e2f825f3861feb23',
        timeOffset: 0,
      ),
      transparency: 0.05,
    );

    setState(() {
      _tileOverlays = {cloudOverlay};
    });
  }

  void _updateTimeOffset(double value) {
    setState(() {
      _timeOffset = value;
      _createTileOverlays();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      margin: const EdgeInsets.only(bottom: 16),
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
            child: Listener(
              onPointerDown: (_) {
                // Prevent parent scroll when touching the map
                FocusScope.of(context).unfocus();
              },
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.position.latitude, widget.position.longitude),
                  zoom: 8,
                ),
                onMapCreated: (controller) {
                  setState(() {
                    _mapController = controller;
                    _isMapLoading = false;
                  });
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
                mapType: MapType.hybrid,
                tileOverlays: _tileOverlays,
                onCameraMove: (_) {
                  if (!_isDragging) {
                    setState(() => _isDragging = true);
                  }
                },
                onCameraIdle: () {
                  setState(() => _isDragging = false);
                },
              ),
            ),
          ),
          if (_isMapLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.tealAccent,
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
} 