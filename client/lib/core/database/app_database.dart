import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('MasterProfileRow')
class MasterProfiles extends Table {
  IntColumn get singleton => integer().withDefault(const Constant(1))();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {singleton};
}

@DataClassName('SharingProfileRow')
class SharingProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get json => text()();
  TextColumn get keyBase64 => text()();
  IntColumn get version => integer()();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ConnectedProfileRow')
class ConnectedProfiles extends Table {
  TextColumn get connectionId => text()();
  TextColumn get peerUserId => text()();
  TextColumn get peerUsername => text().nullable()();
  TextColumn get status => text()();
  TextColumn get direction => text()();
  TextColumn get profileJson => text().nullable()();
  IntColumn get version => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {connectionId};
}

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('PendingConnectionActionRow')
class PendingConnectionActions extends Table {
  TextColumn get id => text()();
  TextColumn get operation => text()();
  TextColumn get connectionId => text().nullable()();
  TextColumn get peerUserId => text().nullable()();
  TextColumn get profileSetId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  MasterProfiles,
  SharingProfiles,
  ConnectedProfiles,
  AppSettings,
  PendingConnectionActions
])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(driftDatabase(
          name: 'nexbook',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.createTable(pendingConnectionActions);
          }
          if (from < 3) {
            await migrator.addColumn(
                connectedProfiles, connectedProfiles.peerUsername);
          }
        },
      );

  Stream<MasterProfileRow?> watchMasterProfile() =>
      select(masterProfiles).watchSingleOrNull();
  Future<void> saveMasterProfile(String json) async {
    await into(masterProfiles).insertOnConflictUpdate(
        MasterProfilesCompanion.insert(json: json, updatedAt: DateTime.now()));
  }

  Stream<List<SharingProfileRow>> watchSharingProfiles() =>
      (select(sharingProfiles)..orderBy([(row) => OrderingTerm.asc(row.id)]))
          .watch();
  Future<void> saveSharingProfile(
      {required String id,
      required String json,
      required String keyBase64,
      required int version,
      bool dirty = true}) async {
    await into(sharingProfiles).insertOnConflictUpdate(
        SharingProfilesCompanion.insert(
            id: id,
            json: json,
            keyBase64: keyBase64,
            version: version,
            dirty: Value(dirty)));
  }

  Future<void> removeSharingProfile(String id) async {
    await (delete(sharingProfiles)..where((row) => row.id.equals(id))).go();
  }

  Future<List<SharingProfileRow>> dirtyProfiles() =>
      (select(sharingProfiles)..where((row) => row.dirty.equals(true))).get();
  Future<void> markProfileSynced(String id) async {
    await (update(sharingProfiles)..where((row) => row.id.equals(id)))
        .write(const SharingProfilesCompanion(dirty: Value(false)));
  }

  Future<void> enqueueConnectionAction({
    required String id,
    required String operation,
    String? connectionId,
    String? peerUserId,
    String? profileSetId,
  }) =>
      into(pendingConnectionActions).insert(
        PendingConnectionActionsCompanion.insert(
          id: id,
          operation: operation,
          connectionId: Value(connectionId),
          peerUserId: Value(peerUserId),
          profileSetId: Value(profileSetId),
          createdAt: DateTime.now(),
        ),
      );

  Future<List<PendingConnectionActionRow>> pendingConnectionQueue() =>
      (select(pendingConnectionActions)
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

  Future<void> removePendingConnectionAction(String id) =>
      (delete(pendingConnectionActions)..where((row) => row.id.equals(id)))
          .go();

  Future<void> removePendingRequest(String peerUserId) =>
      (delete(pendingConnectionActions)
            ..where((row) =>
                row.operation.equals('request') &
                row.peerUserId.equals(peerUserId)))
          .go();

  Future<void> clearAll() => transaction(() async {
        await delete(connectedProfiles).go();
        await delete(sharingProfiles).go();
        await delete(masterProfiles).go();
        await delete(appSettings).go();
        await delete(pendingConnectionActions).go();
      });
}
