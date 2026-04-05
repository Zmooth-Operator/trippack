import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:math';

class OfflineMapService {
  static Future<String> getTileCacheDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final tileDir = Directory('${dir.path}/tiles');
    if (!await tileDir.exists()) await tileDir.create(recursive: true);
    return tileDir.path;
  }

  static String tilePath(String baseDir, int z, int x, int y) {
    return '$baseDir/$z/$x/$y.png';
  }

  static Future<bool> tileExists(String baseDir, int z, int x, int y) async {
    return File(tilePath(baseDir, z, x, y)).exists();
  }

  // Convert lat/lng to tile coordinates
  static (int, int) latLngToTile(double lat, double lng, int zoom) {
    final n = pow(2, zoom);
    final x = ((lng + 180.0) / 360.0 * n).floor();
    final latRad = lat * pi / 180.0;
    final y = ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * n).floor();
    return (x, y);
  }

  static Stream<double> downloadTilesForArea({
    required double lat,
    required double lng,
    required int radiusKm,
  }) async* {
    final baseDir = await getTileCacheDir();
    final tripDir = '$baseDir/${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
    await Directory(tripDir).create(recursive: true);

    // Zoom levels 10-14 for good offline coverage
    const minZoom = 10;
    const maxZoom = 14;

    // Calculate bounding box from radius
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm / (111.0 * cos(lat * pi / 180.0));

    final tiles = <(int, int, int)>[];

    for (int z = minZoom; z <= maxZoom; z++) {
      final (x1, y1) = latLngToTile(lat + latDelta, lng - lngDelta, z);
      final (x2, y2) = latLngToTile(lat - latDelta, lng + lngDelta, z);
      for (int x = x1; x <= x2; x++) {
        for (int y = y1; y <= y2; y++) {
          tiles.add((z, x, y));
        }
      }
    }

    int downloaded = 0;
    for (final (z, x, y) in tiles) {
      final path = '$tripDir/$z-$x-$y.png';
      if (!await File(path).exists()) {
        try {
          final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
          final response = await http.get(Uri.parse(url), headers: {
            'User-Agent': 'TripPack/1.0',
          });
          if (response.statusCode == 200) {
            await File(path).writeAsBytes(response.bodyBytes);
          }
        } catch (_) {}
      }
      downloaded++;
      yield downloaded / tiles.length;
    }
  }

  static Future<String?> getTripTileDir(double lat, double lng) async {
    final baseDir = await getTileCacheDir();
    final tripDir = '$baseDir/${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
    if (await Directory(tripDir).exists()) return tripDir;
    return null;
  }
}