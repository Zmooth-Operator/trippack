import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:drift/drift.dart' show Value;
import 'database.dart';
import 'main.dart';
import 'map_widget.dart';
import 'edit_trip.dart';

class TripScreen extends StatefulWidget {
  final Trip trip;

  const TripScreen({super.key, required this.trip});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  int _currentIndex = 0;
  late Trip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day}.${date.month}.${date.year}';
  }

  Future<void> _openEditScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditTripScreen(trip: _trip)),
    );
    if (result == true) {
      final trips = await database.getAllTrips();
      final updated = trips.firstWhere((t) => t.id == _trip.id, orElse: () => _trip);
      setState(() => _trip = updated);
    }
  }

  Future<void> _uploadDocument(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
      withReadStream: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      await database.insertDocument(DocumentsCompanion(
        tripId: Value(_trip.id),
        type: Value(type),
        fileName: Value(file.name),
        filePath: Value(file.path),
      ));
      setState(() {});
    }
  }

  Future<void> _replaceDocument(Document doc) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      await database.updateDocument(doc.copyWith(
        fileName: Value(file.name),
        filePath: Value(file.path),
      ));
      setState(() {});
    }
  }

  Future<void> _openDocument(Document doc) async {
    if (doc.filePath == null) return;
    await OpenFilex.open(doc.filePath!);
  }

  Future<void> _deleteDocument(int id) async {
    await database.deleteDocument(id);
    setState(() {});
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_trip.name ?? _trip.city,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            if (_trip.country != null)
              Text(_trip.country!,
                  style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textColor),
            color: cardColor,
            onSelected: (value) async {
              if (value == 'edit') {
                await _openEditScreen();
              } else if (value == 'delete') {
                await database.deleteTrip(_trip.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: textColor.withOpacity(0.7), size: 20),
                    const SizedBox(width: 8),
                    Text('Edit trip', style: TextStyle(color: textColor.withOpacity(0.7))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete trip', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildTab(bg, cardColor, textColor),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: cardColor,
        selectedItemColor: isDark ? Colors.white : Colors.black,
        unselectedItemColor: isDark ? Colors.white38 : Colors.black38,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.info_outline), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.folder_outlined), label: 'Documents'),
        ],
      ),
    );
  }

  Widget _buildTab(Color bg, Color cardColor, Color textColor) {
    switch (_currentIndex) {
      case 0: return _overviewTab(cardColor, textColor);
      case 1: return _mapTab();
      case 2: return _documentsTab(cardColor, textColor);
      default: return _overviewTab(cardColor, textColor);
    }
  }

  Widget _overviewTab(Color cardColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _infoRow(Icons.flight_takeoff, 'Departure', _formatDate(_trip.departureDate), textColor),
                const SizedBox(height: 16),
                _infoRow(Icons.flight_land, 'Return', _formatDate(_trip.returnDate), textColor),
                const SizedBox(height: 16),
                _infoRow(Icons.circle_outlined, 'Status', _trip.status, textColor),
                if (_trip.mapRadius != null) ...[
                  const SizedBox(height: 16),
                  _infoRow(Icons.map_outlined, 'Map Radius', '${_trip.mapRadius} km', textColor),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapTab() {
    return TripMapWidget(
      key: ValueKey('${_trip.lat}-${_trip.lng}-${_trip.mapRadius}'),
      city: _trip.city,
      lat: _trip.lat,
      lng: _trip.lng,
      radiusKm: _trip.mapRadius,
    );
  }

  Widget _documentsTab(Color cardColor, Color textColor) {
    final docTypes = [
      'Boarding Pass', 'Hotel Booking', 'Passport Copy',
      'Train Ticket', 'Insurance', 'Tickets & Entries',
      'Vaccination Proof', 'Other',
    ];

    return FutureBuilder<List<Document>>(
      future: database.getDocumentsForTrip(_trip.id),
      builder: (context, snapshot) {
        final docs = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Documents',
                      style: TextStyle(
                          color: textColor.withOpacity(0.5),
                          fontSize: 14,
                          letterSpacing: 1.2)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showUploadSheet(docTypes, cardColor, textColor),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, color: textColor, size: 16),
                          const SizedBox(width: 4),
                          Text('Add', style: TextStyle(color: textColor, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_outlined, size: 64, color: textColor.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('No documents yet',
                            style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 15)),
                        const SizedBox(height: 8),
                        Text('Tap + Add to upload',
                            style: TextStyle(color: textColor.withOpacity(0.2), fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      return Dismissible(
                        key: Key('doc_${doc.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.red),
                        ),
                        onDismissed: (_) => _deleteDocument(doc.id),
                        child: GestureDetector(
                          onTap: doc.filePath != null ? () => _openDocument(doc) : null,
                          onLongPress: () => _showDocumentOptions(doc, cardColor, textColor),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  doc.isUploaded ? Icons.check_circle : Icons.upload_file,
                                  color: doc.isUploaded ? Colors.greenAccent : textColor.withOpacity(0.35),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(doc.type,
                                          style: TextStyle(color: textColor, fontSize: 15)),
                                      if (doc.fileName != null)
                                        Text(doc.fileName!,
                                            style: TextStyle(
                                                color: textColor.withOpacity(0.4), fontSize: 12),
                                            overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (doc.filePath != null)
                                  Icon(Icons.chevron_right, color: textColor.withOpacity(0.2), size: 18)
                                else
                                  const Text('Pending',
                                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showDocumentOptions(Document doc, Color cardColor, Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc.type,
                style: TextStyle(
                    color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (doc.filePath != null)
              ListTile(
                leading: Icon(Icons.open_in_new, color: textColor),
                title: Text('Open', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _openDocument(doc);
                },
              ),
            ListTile(
              leading: Icon(Icons.upload_file, color: textColor),
              title: Text('Replace file', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _replaceDocument(doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteDocument(doc.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadSheet(List<String> docTypes, Color cardColor, Color textColor) {
    final bgColor = themeNotifier.isDark ? AppColors.darkBg : AppColors.lightBg;
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select document type',
                style: TextStyle(
                    color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: docTypes.map((type) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _uploadDocument(type);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: textColor.withOpacity(0.1)),
                  ),
                  child: Text(type, style: TextStyle(color: textColor, fontSize: 14)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: textColor.withOpacity(0.35), size: 18),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}