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

@DriftDatabase(
    tables: [MasterProfiles, SharingProfiles, ConnectedProfiles, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'nexbook'));
  @override
  int get schemaVersion => 1;

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

  Future<void> clearAll() => transaction(() async {
        await delete(connectedProfiles).go();
        await delete(sharingProfiles).go();
        await delete(masterProfiles).go();
        await delete(appSettings).go();
      });
}
