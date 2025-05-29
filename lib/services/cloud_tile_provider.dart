import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';

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
    
    final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000 - (timeOffset * 3600)).round();
    
    final url = urlTemplate
        .replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString())
        .replaceAll('{z}', zoom.toString())
        + '&t=$timestamp';
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final enhancedBytes = await _enhanceCloudImage(response.bodyBytes);
      return Tile(x, y, enhancedBytes);
    }
    return TileProvider.noTile;
  }

  Future<Uint8List> _enhanceCloudImage(Uint8List originalBytes) async {
    final codec = await ui.instantiateImageCodec(originalBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(image, Offset.zero, Paint());

    final paint = Paint()
      ..colorFilter = ColorFilter.matrix([
        1.5, 0, 0, 0, 0,
        0, 1.5, 0, 0, 0,
        0, 0, 1.5, 0, 0,
        0, 0, 0, 1, 0,
      ]);

    canvas.drawImage(image, Offset.zero, paint);

    final picture = recorder.endRecording();
    final enhancedImage = await picture.toImage(image.width, image.height);
    final byteData = await enhancedImage.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }
} 