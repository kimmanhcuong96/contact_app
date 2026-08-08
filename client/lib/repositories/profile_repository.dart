import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart' as db;
import '../core/network/api_client.dart';
import '../core/security/crypto_service.dart';
import '../models/master_profile.dart';
import '../models/sharing_profile.dart';

class ProfileRepository {
  ProfileRepository(this.database, this.api, this.crypto);
  final db.AppDatabase database;
  final ApiClient api;
  final CryptoService crypto;

  Stream<MasterProfile> watchMaster() =>
      database.watchMasterProfile().map((row) =>
          row == null ? MasterProfile.empty : MasterProfile.decode(row.json));
  Stream<List<SharingProfile>> watchSharing() =>
      database.watchSharingProfiles().map((rows) =>
          rows.map((row) => SharingProfile.decode(row.json)).toList());

  Future<void> initializeDefaults() async {
    if ((await database.select(database.sharingProfiles).get()).isNotEmpty) {
      return;
    }
    for (final item in const [
      (
        'Family',
        {'fullName', 'nickname', 'birthday', 'phone', 'email', 'address'}
      ),
      ('Friends', {'fullName', 'nickname', 'phone', 'email', 'instagram'}),
      (
        'Work',
        {'fullName', 'company', 'position', 'phone', 'email', 'linkedIn'}
      ),
      ('Public', {'fullName', 'company', 'position', 'website'}),
    ]) {
      await saveSharing(SharingProfile(
          id: const Uuid().v4(),
          name: item.$1,
          visibleFields: item.$2,
          version: 1));
    }
  }

  Future<void> saveMaster(MasterProfile profile) async {
    await database.saveMasterProfile(profile.encode());
    final rows = await database.select(database.sharingProfiles).get();
    for (final row in rows) {
      final item =
          SharingProfile.decode(row.json).copyWith(version: row.version + 1);
      await database.saveSharingProfile(
          id: row.id,
          json: item.encode(),
          keyBase64: row.keyBase64,
          version: item.version);
    }
  }

  Future<void> saveSharing(SharingProfile profile) async {
    final existing = await (database.select(database.sharingProfiles)
          ..where((row) => row.id.equals(profile.id)))
        .getSingleOrNull();
    final key = existing?.keyBase64 ??
        await crypto.encodeKey(await crypto.newProfileKey());
    await database.saveSharingProfile(
        id: profile.id,
        json: profile.encode(),
        keyBase64: key,
        version: profile.version);
  }

  Future<void> deleteSharing(String id) => database.removeSharingProfile(id);

  Future<void> sync() async {
    final master = await database.watchMasterProfile().first;
    final fields = master == null
        ? const <String, String>{}
        : MasterProfile.decode(master.json).fields;
    final remoteResponse =
        await api.dio.get<Map<String, dynamic>>('/profile-sets');
    final remoteItems = remoteResponse.data?['items'] as List? ?? const [];
    final remoteClientIds =
        remoteItems.map((item) => (item as Map)['clientId'] as String).toSet();
    final localRows = await database.select(database.sharingProfiles).get();
    for (final row in localRows
        .where((row) => row.dirty || !remoteClientIds.contains(row.id))) {
      final sharing = SharingProfile.decode(row.json);
      final view = <String, dynamic>{
        'fields': {
          for (final entry in fields.entries)
            if (sharing.visibleFields.contains(entry.key))
              entry.key: entry.value
        }
      };
      final encrypted =
          await crypto.encryptJson(view, crypto.decodeKey(row.keyBase64));
      await api.dio.put<void>('/profile-sets/${row.id}',
          data: {'version': row.version, 'encryptedBlob': encrypted.toJson()});
      await database.markProfileSynced(row.id);
    }
  }

  Future<String> exportJson() async {
    final master = await database.watchMasterProfile().first;
    final profiles = await database.select(database.sharingProfiles).get();
    final settings = await database.select(database.appSettings).get();
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'nexbook-export-v1',
      'masterProfile': master == null
          ? MasterProfile.empty.toJson()
          : MasterProfile.decode(master.json).toJson(),
      'sharingProfiles': profiles
          .map((row) => SharingProfile.decode(row.json).toJson())
          .toList(),
      'settings': {for (final row in settings) row.key: row.value},
    });
  }

  Future<void> importJson(String raw) async {
    final value = jsonDecode(raw) as Map<String, dynamic>;
    if (value['format'] != 'nexbook-export-v1') {
      throw const FormatException('Unsupported backup format');
    }
    await saveMaster(
        MasterProfile.fromJson(value['masterProfile'] as Map<String, dynamic>));
    for (final item in value['sharingProfiles'] as List) {
      final profile =
          SharingProfile.fromJson(Map<String, dynamic>.from(item as Map));
      await saveSharing(profile.copyWith(version: profile.version + 1));
    }
    final settings =
        Map<String, dynamic>.from(value['settings'] as Map? ?? const {});
    for (final entry in settings.entries) {
      await database.into(database.appSettings).insertOnConflictUpdate(
          db.AppSettingsCompanion.insert(
              key: entry.key, value: '${entry.value}'));
    }
  }
}
