import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'offline_map_service.dart';

class TripMapWidget extends StatefulWidget {
  final String city;
  final double? lat;
  final double? lng;
  final int? radiusKm;

  const TripMapWidget({
    super.key,
    required this.city,
    this.lat,
    this.lng,
    this.radiusKm,
  });

  @override
  State<TripMapWidget> createState() => _TripMapWidgetState();
}

class _TripMapWidgetState extends State<TripMapWidget> {
  Position? _currentPosition;
  bool _loadingLocation = true;
  bool _downloading = false;
  double _downloadProgress = 0.0;
  String? _tileDir;
  bool _offlineAvailable = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _checkOfflineTiles();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loadingLocation = false);
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _loadingLocation = false);
          return;
        }
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _loadingLocation = false;
      });
    } catch (_) {
      setState(() => _loadingLocation = false);
    }
  }

  Future<void> _checkOfflineTiles() async {
    if (widget.lat == null || widget.lng == null) return;
    final dir = await OfflineMapService.getTripTileDir(widget.lat!, widget.lng!);
    setState(() {
      _tileDir = dir;
      _offlineAvailable = dir != null;
    });
  }

  Future<void> _downloadOfflineMap() async {
    if (widget.lat == null || widget.lng == null) return;
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    final stream = OfflineMapService.downloadTilesForArea(
      lat: widget.lat!,
      lng: widget.lng!,
      radiusKm: widget.radiusKm ?? 20,
    );
    await for (final progress in stream) {
      setState(() => _downloadProgress = progress);
    }
    await _checkOfflineTiles();
    setState(() => _downloading = false);
  }

  LatLng get _center {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    if (widget.lat != null && widget.lng != null) {
      return LatLng(widget.lat!, widget.lng!);
    }
    return const LatLng(48.1351, 11.5820); // Munich fallback
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_loadingLocation)
          Container(
            color: const Color(0xFF0D1117),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white38),
            ),
          )
        else
          FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.trippack',
                tileProvider: _offlineAvailable && _tileDir != null
                    ? _OfflineTileProvider(_tileDir!)
                    : NetworkTileProvider(),
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

        // GPS Badge
        Positioned(
          top: 16,
          left: 16,
          child: _badge(
            Icons.gps_fixed,
            _currentPosition != null ? 'GPS Active' : 'No GPS',
            _currentPosition != null ? Colors.greenAccent : Colors.orange,
          ),
        ),

        // Offline Badge
        Positioned(
          top: 16,
          right: 16,
          child: _badge(
            _offlineAvailable ? Icons.wifi_off : Icons.wifi,
            _offlineAvailable ? 'Offline Ready' : 'Online',
            _offlineAvailable ? Colors.greenAccent : Colors.blueAccent,
          ),
        ),

        // Download Button
        if (!_offlineAvailable && !_downloading && widget.lat != null)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _downloadOfflineMap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Download Offline Map',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Download Progress
        if (_downloading)
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Downloading map... ${(_downloadProgress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _OfflineTileProvider extends TileProvider {
  final String tileDir;
  _OfflineTileProvider(this.tileDir);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final path = '$tileDir/${coordinates.z}-${coordinates.x}-${coordinates.y}.png';
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return NetworkImage(
      'https://tile.openstreetmap.org/${coordinates.z}/${coordinates.x}/${coordinates.y}.png',
    );
  }
}