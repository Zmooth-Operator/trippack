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
  final TextEditingController _nameController = TextEditingController();
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
    _nameController.text = widget.trip.name ?? widget.trip.city;
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
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _nameController.text != (widget.trip.name ?? widget.trip.city) ||
        _selectedCity != widget.trip.city ||
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
    final isDark = themeNotifier.isDark;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: _dateRange,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      builder: (context, child) => Theme(
        data: isDark
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.accent,
                  onPrimary: AppColors.darkBg,
                  surface: AppColors.darkCard,
                  onSurface: Colors.white,
                  secondaryContainer: Color(0xFF2A2A4E),
                  onSecondaryContainer: Colors.white,
                ),
              )
            : ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.accent,
                  onPrimary: Colors.black,
                  surface: AppColors.lightCard,
                  onSurface: Colors.black,
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
      name: Value(_nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : widget.trip.name),
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
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Trip',
          style: TextStyle(
              color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Trip Name', textColor),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Trip name',
                hintStyle: TextStyle(color: textColor.withOpacity(0.35)),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                prefixIcon:
                    Icon(Icons.label_outline, color: textColor.withOpacity(0.35)),
              ),
            ),
            const SizedBox(height: 28),
            _sectionLabel('Destination', textColor),
            const SizedBox(height: 8),
            TextField(
              controller: _cityController,
              style: TextStyle(color: textColor),
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'City or country',
                hintStyle: TextStyle(color: textColor.withOpacity(0.35)),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.35)),
                suffixIcon: _isSearching
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: textColor.withOpacity(0.35), strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: textColor.withOpacity(0.05), height: 1),
                  itemBuilder: (context, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      leading: Icon(Icons.location_on_outlined,
                          color: textColor.withOpacity(0.35), size: 20),
                      title: Text(s['city']!,
                          style: TextStyle(color: textColor, fontSize: 15)),
                      subtitle: Text(s['country']!,
                          style: TextStyle(
                              color: textColor.withOpacity(0.4), fontSize: 13)),
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

            _sectionLabel('Travel Dates', textColor),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDateRange,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.date_range, color: textColor.withOpacity(0.5), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatRange(),
                        style: TextStyle(
                          color: _dateRange != null
                              ? textColor
                              : textColor.withOpacity(0.35),
                          fontSize: 15,
                          fontWeight: _dateRange != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: textColor.withOpacity(0.35)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            Row(
              children: [
                _sectionLabel('Map Download Radius', textColor),
                const Spacer(),
                if (_offlineReady)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                      SizedBox(width: 4),
                      Text('Downloaded',
                          style:
                              TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children:
                  _radiusOptions.entries.toList().asMap().entries.map((e) {
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
                            ? AppColors.accentBlue
                            : cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        option.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : textColor.withOpacity(0.4),
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
                  backgroundColor: isDark ? Colors.white : Colors.black,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  disabledBackgroundColor: textColor.withOpacity(0.08),
                  disabledForegroundColor: textColor.withOpacity(0.25),
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

  Widget _sectionLabel(String text, Color textColor) {
    return Text(
      text,
      style: TextStyle(
          color: textColor.withOpacity(0.5),
          fontSize: 13,
          letterSpacing: 1.1),
    );
  }
}