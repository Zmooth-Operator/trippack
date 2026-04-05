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
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_trip.city,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            if (_trip.country != null)
              Text(_trip.country!,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF16213E),
            onSelected: (value) async {
              if (value == 'edit') {
                await _openEditScreen();
              } else if (value == 'delete') {
                await database.deleteTrip(_trip.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                    SizedBox(width: 8),
                    Text('Edit trip', style: TextStyle(color: Colors.white70)),
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
      body: _buildTab(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF16213E),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
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

  Widget _buildTab() {
    switch (_currentIndex) {
      case 0: return _overviewTab();
      case 1: return _mapTab();
      case 2: return _documentsTab();
      default: return _overviewTab();
    }
  }

  Widget _overviewTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _infoRow(Icons.flight_takeoff, 'Departure', _formatDate(_trip.departureDate)),
                const SizedBox(height: 16),
                _infoRow(Icons.flight_land, 'Return', _formatDate(_trip.returnDate)),
                const SizedBox(height: 16),
                _infoRow(Icons.circle_outlined, 'Status', _trip.status),
                if (_trip.mapRadius != null) ...[
                  const SizedBox(height: 16),
                  _infoRow(Icons.map_outlined, 'Map Radius', '${_trip.mapRadius} km'),
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

  Widget _documentsTab() {
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
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, letterSpacing: 1.2)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showUploadSheet(docTypes),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Add', style: TextStyle(color: Colors.white, fontSize: 13)),
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
                        Icon(Icons.folder_outlined, size: 64, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('No documents yet',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15)),
                        const SizedBox(height: 8),
                        Text('Tap + Add to upload',
                            style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 13)),
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
                          onLongPress: () => _showDocumentOptions(doc),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16213E),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  doc.isUploaded ? Icons.check_circle : Icons.upload_file,
                                  color: doc.isUploaded ? Colors.greenAccent : Colors.white38,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(doc.type,
                                          style: const TextStyle(color: Colors.white, fontSize: 15)),
                                      if (doc.fileName != null)
                                        Text(doc.fileName!,
                                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                                            overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (doc.filePath != null)
                                  const Icon(Icons.chevron_right, color: Colors.white24, size: 18)
                                else
                                  Text('Pending', style: TextStyle(color: Colors.orange, fontSize: 12)),
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

  void _showDocumentOptions(Document doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc.type,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (doc.filePath != null)
              ListTile(
                leading: const Icon(Icons.open_in_new, color: Colors.white),
                title: const Text('Open', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _openDocument(doc);
                },
              ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Colors.white),
              title: const Text('Replace file', style: TextStyle(color: Colors.white)),
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

  void _showUploadSheet(List<String> docTypes) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select document type',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}