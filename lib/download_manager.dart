import 'dart:async';
import 'package:flutter/foundation.dart';
import 'offline_map_service.dart';

class DownloadManager extends ChangeNotifier {
  static final DownloadManager instance = DownloadManager._();
  DownloadManager._();

  bool isDownloading = false;
  double progress = 0.0;
  String? currentCity;

  Future<void> downloadMap({
    required double lat,
    required double lng,
    required int radiusKm,
    required String city,
  }) async {
    if (isDownloading) return;
    isDownloading = true;
    currentCity = city;
    progress = 0.0;
    notifyListeners();

    try {
      final stream = OfflineMapService.downloadTilesForArea(
        lat: lat,
        lng: lng,
        radiusKm: radiusKm,
      );
      await for (final p in stream) {
        progress = p;
        notifyListeners();
      }
    } catch (_) {}

    isDownloading = false;
    progress = 0.0;
    currentCity = null;
    notifyListeners();
  }
}