import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../services/light_pollution_service.dart';

class BortleMap extends StatefulWidget {
  final Position position;
  final Map<String, dynamic> lightPollutionData;

  const BortleMap({
    super.key,
    required this.position,
    required this.lightPollutionData,
  });

  @override
  State<BortleMap> createState() => _BortleMapState();
}

class _BortleMapState extends State<BortleMap> {
  GoogleMapController? _mapController;
  bool _isMapLoading = true;
  Set<TileOverlay> _tileOverlays = {};

  @override
  void initState() {
    super.initState();
    _createTileOverlays();
  }

  void _createTileOverlays() {
    final TileOverlay lightPollutionOverlay = TileOverlay(
      tileOverlayId: const TileOverlayId('light_pollution_overlay'),
      tileProvider: UrlTileProvider(
        urlTemplate: 'https://www.lightpollutionmap.info/tiles/wa_2015/{z}/{x}/{y}.png',
      ),
      transparency: 0.3,
    );

    setState(() {
      _tileOverlays = {lightPollutionOverlay};
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
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
            ),
          ),
          if (_isMapLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Colors.tealAccent,
              ),
            ),
          // Bortle Scale Info
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.tealAccent.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bortle Scale: ${widget.lightPollutionData['bortleScale']}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.lightPollutionData['description'],
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
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

class UrlTileProvider implements TileProvider {
  final String urlTemplate;

  UrlTileProvider({required this.urlTemplate});

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) return TileProvider.noTile;
    
    final url = urlTemplate
        .replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString())
        .replaceAll('{z}', zoom.toString());
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return Tile(x, y, response.bodyBytes);
      }
    } catch (e) {
      print('Error loading tile: $e');
    }
    return TileProvider.noTile;
  }
} 