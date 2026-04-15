import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().nullable()();  // NEU
  TextColumn get city => text()();
  TextColumn get country => text().nullable()();
  DateTimeColumn get departureDate => dateTime().nullable()();
  DateTimeColumn get returnDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('Planned'))();
  IntColumn get mapRadius => integer().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId => integer().references(Trips, #id)();
  TextColumn get type => text()();
  TextColumn get fileName => text().nullable()();
  TextColumn get filePath => text().nullable()();
  BoolColumn get isUploaded => boolean().withDefault(const Constant(true))();
}

@DriftDatabase(tables: [Trips, Documents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(trips, trips.lat);
        await m.addColumn(trips, trips.lng);
      }
      if (from < 3) {
        await m.addColumn(documents, documents.filePath);
      }
      if (from < 4) {
        await m.addColumn(trips, trips.name);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'trippack_db');
  }

  String _computeStatus(DateTime? departure, DateTime? returnDate) {
    final now = DateTime.now();
    if (departure == null) return 'Planned';
    if (returnDate != null && returnDate.isBefore(now)) return 'Completed';
    if (departure.isBefore(now) || departure.isAtSameMomentAs(now)) return 'Active';
    return 'Planned';
  }

  Future<List<Trip>> getAllTrips() async {
    final all = await select(trips).get();
    for (final trip in all) {
      final computed = _computeStatus(trip.departureDate, trip.returnDate);
      if (computed != trip.status) {
        await updateTrip(trip.copyWith(status: computed));
      }
    }
    return select(trips).get();
  }

  Stream<List<Trip>> watchAllTrips() {
    return select(trips).watch().asyncMap((list) async {
      for (final trip in list) {
        final computed = _computeStatus(trip.departureDate, trip.returnDate);
        if (computed != trip.status) {
          await updateTrip(trip.copyWith(status: computed));
        }
      }
      final updated = await select(trips).get();
      updated.sort((a, b) {
        const order = {'Active': 0, 'Planned': 1, 'Completed': 2};
        final statusCompare = (order[a.status] ?? 1).compareTo(order[b.status] ?? 1);
        if (statusCompare != 0) return statusCompare;
        if (a.departureDate == null) return 1;
        if (b.departureDate == null) return -1;
        return a.departureDate!.compareTo(b.departureDate!);
      });
      return updated;
    });
  }

  Future<int> insertTrip(TripsCompanion trip) => into(trips).insert(trip);

  Future<void> updateTrip(Trip trip) => update(trips).replace(trip);

  Future<void> deleteTrip(int id) =>
      (delete(trips)..where((t) => t.id.equals(id))).go();

  Future<List<Document>> getDocumentsForTrip(int tripId) =>
      (select(documents)..where((d) => d.tripId.equals(tripId))).get();

  Future<int> insertDocument(DocumentsCompanion doc) =>
      into(documents).insert(doc);

  Future<void> updateDocument(Document doc) =>
      update(documents).replace(doc);

  Future<void> deleteDocument(int id) =>
(delete(documents)..where((d) => d.id.equals(id))).go();
}