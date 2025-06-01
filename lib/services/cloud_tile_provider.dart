import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class CloudTileProvider implements TileProvider {
  final String urlTemplate;
  final double timeOffset;

  CloudTileProvider({
    required this.urlTemplate,
    this.timeOffset = 0,
  });

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    if (zoom == null) return TileProvider.noTile;

    // Add timestamp to prevent caching
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = '${urlTemplate.replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString())
        .replaceAll('{z}', zoom.toString())}&tm=${timeOffset.toInt()}&_=$timestamp';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        return Tile(256, 256, bytes);
      }
    } catch (e) {
      print('Error loading tile: $e');
    }

    return TileProvider.noTile;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> onTileOverlayAdded() async {}

  @override
  Future<void> onTileOverlayRemoved() async {}
} 