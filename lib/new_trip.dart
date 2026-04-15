import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'database.dart';
import 'main.dart';
import 'offline_map_service.dart';
import 'download_manager.dart';

class NewTripScreen extends StatefulWidget {
  const NewTripScreen({super.key});

  @override
  State<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends State<NewTripScreen> {
  int _step = 0;
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  DateTimeRange? _dateRange;
  int? _selectedRadius;
  String? _selectedCity;
  String? _selectedCountry;
  double? _selectedLat;
  double? _selectedLng;
  List<Map<String, String>> _suggestions = [];
  bool _isSearching = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _downloadComplete = false;
  Timer? _debounce;
  String _lastGeneratedName = '';

  final List<String> _docTypes = [
    'Boarding Pass', 'Hotel Booking', 'Passport Copy',
    'Train Ticket', 'Insurance', 'Tickets & Entries',
    'Vaccination Proof', 'Other',
  ];

  final Map<String, String?> _docSelections = {};

  final List<Map<String, dynamic>> _quickCities = [
    {'city': 'Paris', 'country': 'France', 'lat': 48.8566, 'lng': 2.3522},
    {'city': 'Rome', 'country': 'Italy', 'lat': 41.9028, 'lng': 12.4964},
    {'city': 'Barcelona', 'country': 'Spain', 'lat': 41.3851, 'lng': 2.1734},
    {'city': 'Amsterdam', 'country': 'Netherlands', 'lat': 52.3676, 'lng': 4.9041},
    {'city': 'Tokyo', 'country': 'Japan', 'lat': 35.6762, 'lng': 139.6503},
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _cityController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _generateTripName() {
    final city = _selectedCity ?? _cityController.text.split(',').first.trim();
    if (city.isEmpty) return;
    String monthYear = '';
    if (_dateRange != null) {
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final m = months[_dateRange!.start.month - 1];
      final y = _dateRange!.start.year;
      monthYear = ', $m $y';
    }
    final generated = '$city$monthYear';
    if (_nameController.text.isEmpty || _nameController.text == _lastGeneratedName) {
      _nameController.text = generated;
      _lastGeneratedName = generated;
    }
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
      final response = await http.get(Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&featuretype=city&accept-language=en',
      ), headers: {'User-Agent': 'TripPack/1.0'});
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
    if (picked != null) {
      setState(() => _dateRange = picked);
      _generateTripName();
    }
  }

  String _formatRange() {
    if (_dateRange == null) return 'Select dates';
    final start = '${_dateRange!.start.day}.${_dateRange!.start.month}.${_dateRange!.start.year}';
    final end = '${_dateRange!.end.day}.${_dateRange!.end.month}.${_dateRange!.end.year}';
    return '$start — $end';
  }

  Future<void> _pickFileForDoc(String type) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _docSelections[type] = result.files.first.name);
    }
  }

  Future<void> _downloadMap() async {
    if (_selectedLat == null || _selectedLng == null || _selectedRadius == null) return;

    void listener() {
      if (!mounted) return;
      setState(() {
        _downloadProgress = DownloadManager.instance.progress;
        _isDownloading = DownloadManager.instance.isDownloading;
        if (!DownloadManager.instance.isDownloading && _downloadProgress >= 0.99) {
          _downloadComplete = true;
        }
      });
      if (!DownloadManager.instance.isDownloading) {
        DownloadManager.instance.removeListener(listener);
      }
    }

    DownloadManager.instance.addListener(listener);
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadComplete = false;
    });

    DownloadManager.instance.downloadMap(
      lat: _selectedLat!,
      lng: _selectedLng!,
      radiusKm: _selectedRadius!,
      city: _selectedCity ?? _cityController.text,
    );
  }

  Future<void> _saveTrip() async {
    final tripName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_selectedCity ?? _cityController.text.split(',').first.trim());

    final tripId = await database.insertTrip(TripsCompanion(
      name: Value(tripName),
      city: Value(_selectedCity ?? _cityController.text),
      country: Value(_selectedCountry),
      departureDate: Value(_dateRange?.start),
      returnDate: Value(_dateRange?.end),
      status: const Value('Planned'),
      mapRadius: Value(_selectedRadius),
      lat: Value(_selectedLat),
      lng: Value(_selectedLng),
    ));
    for (final entry in _docSelections.entries) {
      await database.insertDocument(DocumentsCompanion(
        tripId: Value(tripId),
        type: Value(entry.key),
        fileName: Value(entry.value),
        isUploaded: Value(entry.value != null),
      ));
    }
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
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
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => _step == 0 ? Navigator.pop(context) : setState(() => _step--),
        ),
        title: Text('Step ${_step + 1} of 3',
            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _stepCityAndDetails();
      case 1: return _stepDocuments();
      case 2: return _stepMap();
      default: return _stepCityAndDetails();
    }
  }

  Widget _stepCityAndDetails() {
    final isDark = themeNotifier.isDark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plan your trip',
            style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 32),

        // Trip Name
        TextField(
          controller: _nameController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Trip name (auto-generated)',
            hintStyle: TextStyle(color: textColor.withOpacity(0.35)),
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: Icon(Icons.label_outline, color: textColor.withOpacity(0.35)),
          ),
        ),

        const SizedBox(height: 16),

        // Stadtsuche
        TextField(
          controller: _cityController,
          style: TextStyle(color: textColor),
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Where are you going?',
            hintStyle: TextStyle(color: textColor.withOpacity(0.35)),
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            prefixIcon: Icon(Icons.search, color: textColor.withOpacity(0.35)),
            suffixIcon: _isSearching ? Padding(
              padding: const EdgeInsets.all(12),
              child: CircularProgressIndicator(color: textColor.withOpacity(0.35), strokeWidth: 2),
            ) : null,
          ),
        ),

        // Suggestions
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(color: textColor.withOpacity(0.05), height: 1),
              itemBuilder: (context, i) {
                final s = _suggestions[i];
                return ListTile(
                  leading: Icon(Icons.location_on_outlined, color: textColor.withOpacity(0.35), size: 20),
                  title: Text(s['city']!, style: TextStyle(color: textColor, fontSize: 15)),
                  subtitle: Text(s['country']!, style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 13)),
                  onTap: () {
                    setState(() {
                      _selectedCity = s['city'];
                      _selectedCountry = s['country'];
                      _selectedLat = double.tryParse(s['lat'] ?? '');
                      _selectedLng = double.tryParse(s['lng'] ?? '');
                      _cityController.text = s['display']!;
                      _suggestions = [];
                    });
                    _generateTripName();
                  },
                );
              },
            ),
          ),
        ],

        // Quick Cities
        if (_suggestions.isEmpty && _cityController.text.isEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _quickCities.map((c) => ActionChip(
              label: Text(c['city'] as String, style: TextStyle(color: textColor)),
              backgroundColor: cardColor,
              onPressed: () {
                setState(() {
                  _selectedCity = c['city'] as String;
                  _selectedCountry = c['country'] as String;
                  _selectedLat = c['lat'] as double;
                  _selectedLng = c['lng'] as double;
                  _cityController.text = '${c['city']}, ${c['country']}';
                  _suggestions = [];
                });
                _generateTripName();
              },
            )).toList(),
          ),
        ],

        const SizedBox(height: 16),

        // Datum
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
                Icon(Icons.date_range, color: textColor.withOpacity(0.5)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatRange(),
                    style: TextStyle(
                      color: _dateRange != null ? textColor : textColor.withOpacity(0.35),
                      fontSize: 15,
                      fontWeight: _dateRange != null ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: textColor.withOpacity(0.35)),
              ],
            ),
          ),
        ),

        const Spacer(),
        _nextButton('Next'),
      ],
    );
  }

  Widget _stepDocuments() {
    final isDark = themeNotifier.isDark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Documents',
            style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Upload now or add later',
            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 16)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: _docTypes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final type = _docTypes[i];
              final fileName = _docSelections[type];
              final isUploaded = fileName != null;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isUploaded ? Colors.greenAccent.withOpacity(0.08) : cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isUploaded ? Colors.greenAccent.withOpacity(0.3) : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(isUploaded ? Icons.check_circle : Icons.upload_file,
                        color: isUploaded ? Colors.greenAccent : textColor.withOpacity(0.35)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(type, style: TextStyle(color: textColor, fontSize: 15)),
                          if (isUploaded)
                            Text(fileName,
                                style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _pickFileForDoc(type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isUploaded
                              ? Colors.greenAccent.withOpacity(0.1)
                              : textColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          isUploaded ? 'Change' : 'Upload',
                          style: TextStyle(
                            color: isUploaded ? Colors.greenAccent : textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _nextButton('Next'),
      ],
    );
  }

  Widget _stepMap() {
    final isDark = themeNotifier.isDark;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? Colors.white : Colors.black;
    final radii = [('20 km', '~50 MB', 20), ('50 km', '~120 MB', 50), ('100 km', '~280 MB', 100)];
    final hasCoords = _selectedLat != null && _selectedLng != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Download Map',
            style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          hasCoords
              ? 'Download a map for offline use. You can also do this later.'
              : 'Search for a city in Step 1 to enable map download. You can also add a map later.',
          style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 15),
        ),
        const SizedBox(height: 24),
        ...radii.map((r) {
          final isThisOne = _selectedRadius == r.$3;
          final isDownloadingThis = _isDownloading && isThisOne;
          final isDownloaded = _downloadComplete && isThisOne;
          final isLocked = (_isDownloading || _downloadComplete) && !isThisOne;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: hasCoords && !_isDownloading && !_downloadComplete ? () async {
                setState(() {
                  _selectedRadius = r.$3;
                  _downloadComplete = false;
                });
                await _downloadMap();
              } : null,
              child: Opacity(
                opacity: (!hasCoords || isLocked) ? 0.3 : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDownloaded ? Colors.greenAccent.withOpacity(0.08) : cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDownloaded ? Colors.greenAccent.withOpacity(0.4) : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isDownloaded ? Icons.check_circle : Icons.download,
                            color: isDownloaded ? Colors.greenAccent : textColor.withOpacity(0.5),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text('Radius ${r.$1}',
                              style: TextStyle(color: textColor, fontSize: 16)),
                          const Spacer(),
                          if (isDownloaded)
                            const Text('Ready', style: TextStyle(color: Colors.greenAccent, fontSize: 13))
                          else if (isDownloadingThis)
                            Text('${(_downloadProgress * 100).toInt()}%',
                                style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 13))
                          else
                            Text(r.$2, style: TextStyle(color: textColor.withOpacity(0.35), fontSize: 14)),
                        ],
                      ),
                      if (isDownloadingThis) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: textColor.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(textColor.withOpacity(0.5)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (_isDownloading || _downloadComplete) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _downloadComplete ? Icons.check_circle_outline : Icons.download_outlined,
                color: textColor.withOpacity(0.35),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                _downloadComplete
                    ? 'Map ready. You can continue.'
                    : 'Downloading in background. You can continue.',
                style: TextStyle(color: textColor.withOpacity(0.35), fontSize: 13),
              ),
            ],
          ),
        ],
        const Spacer(),
        _nextButton('Create Trip', onPressed: _saveTrip),
      ],
    );
  }

  Widget _nextButton(String label, {VoidCallback? onPressed}) {
    final isDark = themeNotifier.isDark;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed ?? () => setState(() => _step++),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}