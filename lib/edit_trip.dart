import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'database.dart';
import 'main.dart';
import 'offline_map_service.dart';

class EditTripScreen extends StatefulWidget {
  final Trip trip;

  const EditTripScreen({super.key, required this.trip});

  @override
  State<EditTripScreen> createState() => _EditTripScreenState();
}

class _EditTripScreenState extends State<EditTripScreen> {
  final TextEditingController _cityController = TextEditingController();
  DateTimeRange? _dateRange;
  int? _mapRadius;
  String? _selectedCity;
  String? _selectedCountry;
  double? _selectedLat;
  double? _selectedLng;
  List<Map<String, String>> _suggestions = [];
  bool _isSearching = false;
  bool _offlineReady = false;
  Timer? _debounce;

  final _radiusOptions = <int?, String>{
    null: 'Skip',
    20: '20 km',
    50: '50 km',
    100: '100 km',
  };

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.trip.city;
    _selectedCountry = widget.trip.country;
    _selectedLat = widget.trip.lat;
    _selectedLng = widget.trip.lng;
    _mapRadius = widget.trip.mapRadius;
    _cityController.text = widget.trip.country != null
        ? '${widget.trip.city}, ${widget.trip.country}'
        : widget.trip.city;
    if (widget.trip.departureDate != null && widget.trip.returnDate != null) {
      _dateRange = DateTimeRange(
        start: widget.trip.departureDate!,
        end: widget.trip.returnDate!,
      );
    }
    _checkOfflineStatus();
  }

  Future<void> _checkOfflineStatus() async {
    if (widget.trip.lat == null || widget.trip.lng == null) return;
    final dir = await OfflineMapService.getTripTileDir(
        widget.trip.lat!, widget.trip.lng!);
    if (mounted) setState(() => _offlineReady = dir != null);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cityController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _selectedCity != widget.trip.city ||
        _selectedCountry != widget.trip.country ||
        _dateRange?.start != widget.trip.departureDate ||
        _dateRange?.end != widget.trip.returnDate ||
        _selectedLat != widget.trip.lat ||
        _selectedLng != widget.trip.lng ||
        _mapRadius != widget.trip.mapRadius;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchCities(query);
    });
  }

  Future<void> _searchCities(String query) async {
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&featuretype=city&accept-language=en',
        ),
        headers: {'User-Agent': 'TripPack/1.0'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        setState(() {
          _suggestions = data.map<Map<String, String>>((item) {
            final parts = (item['display_name'] as String).split(', ');
            return {
              'city': parts.first,
              'country': parts.last,
              'display': '${parts.first}, ${parts.last}',
              'lat': item['lat'] as String,
              'lng': item['lon'] as String,
            };
          }).toList();
        });
      }
    } catch (_) {}
    setState(() => _isSearching = false);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: _dateRange,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFCC00),
            onPrimary: Color(0xFF1A1A2E),
            surface: Color(0xFF16213E),
            onSurface: Colors.white,
            secondaryContainer: Color(0xFF2A2A4E),
            onSecondaryContainer: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  String _formatRange() {
    if (_dateRange == null) return 'Select dates';
    final start =
        '${_dateRange!.start.day}.${_dateRange!.start.month}.${_dateRange!.start.year}';
    final end =
        '${_dateRange!.end.day}.${_dateRange!.end.month}.${_dateRange!.end.year}';
    return '$start — $end';
  }

  Future<void> _saveChanges() async {
    if (_selectedCity == null || _selectedCity!.trim().isEmpty) return;

    final updated = widget.trip.copyWith(
      city: _selectedCity!,
      country: Value(_selectedCountry),
      departureDate: Value(_dateRange?.start),
      returnDate: Value(_dateRange?.end),
      lat: Value(_selectedLat),
      lng: Value(_selectedLng),
      mapRadius: Value(_mapRadius),
    );

    await database.updateTrip(updated);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Trip',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Destination'),
            const SizedBox(height: 8),
            TextField(
              controller: _cityController,
              style: const TextStyle(color: Colors.white),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'City or country',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF16213E),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white38, strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.white.withOpacity(0.05), height: 1),
                  itemBuilder: (context, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined,
                          color: Colors.white38, size: 20),
                      title: Text(s['city']!,
                          style: const TextStyle(color: Colors.white, fontSize: 15)),
                      subtitle: Text(s['country']!,
                          style: const TextStyle(color: Colors.white38, fontSize: 13)),
                      onTap: () {
                        setState(() {
                          _selectedCity = s['city'];
                          _selectedCountry = s['country'];
                          _selectedLat = double.tryParse(s['lat'] ?? '');
                          _selectedLng = double.tryParse(s['lng'] ?? '');
                          _cityController.text = s['display']!;
                          _suggestions = [];
                        });
                      },
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 28),

            _sectionLabel('Travel Dates'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.white54, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatRange(),
                        style: TextStyle(
                          color: _dateRange != null ? Colors.white : Colors.white38,
                          fontSize: 15,
                          fontWeight: _dateRange != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Map Radius Header
            Row(
              children: [
                _sectionLabel('Map Download Radius'),
                const Spacer(),
                if (_offlineReady)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                      SizedBox(width: 4),
                      Text('Downloaded',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: _radiusOptions.entries.toList().asMap().entries.map((e) {
                final index = e.key;
                final option = e.value;
                final isLast = index == _radiusOptions.length - 1;
                final isSelected = _mapRadius == option.key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mapRadius = option.key),
                    child: Container(
                      margin: EdgeInsets.only(right: isLast ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        option.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _hasChanges ? _saveChanges : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A1A2E),
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 13,
          letterSpacing: 1.1),
    );
  }
}