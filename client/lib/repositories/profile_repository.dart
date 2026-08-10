import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/database/app_database.dart' as db;
import '../core/network/api_client.dart';
import '../models/master_profile.dart';
import '../models/sharing_profile.dart';

class ProfileRepository {
  ProfileRepository(this.database, this.api);
  final db.AppDatabase database;
  final ApiClient api;
  Future<void>? _activeSync;
  final _localChanges = StreamController<void>.broadcast();

  Stream<void> get localChanges => _localChanges.stream;

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
    _localChanges.add(null);
  }

  Future<void> saveSharing(SharingProfile profile) async {
    final existing = await (database.select(database.sharingProfiles)
          ..where((row) => row.id.equals(profile.id)))
        .getSingleOrNull();
    await database.saveSharingProfile(
        id: profile.id,
        json: profile.encode(),
        keyBase64: existing?.keyBase64 ?? '',
        version: profile.version);
    _localChanges.add(null);
  }

  Future<void> deleteSharing(String id) async {
    final assigned = await (database.select(database.connectedProfiles)
          ..where((row) =>
              row.assignedProfileId.equals(id) &
              row.status.isIn(const ['connected', 'disabled'])))
        .get();
    if (assigned.isNotEmpty) {
      throw SharingProfileInUseException(assigned.length);
    }
    await database.removeSharingProfile(id);
  }

  Future<void> sync() {
    final active = _activeSync;
    if (active != null) return active;
    final future = _sync();
    _activeSync = future;
    return future.whenComplete(() {
      if (identical(_activeSync, future)) _activeSync = null;
    });
  }

  Future<void> _sync() async {
    final master = await database.watchMasterProfile().first;
    final fields = master == null
        ? const <String, String>{}
        : MasterProfile.decode(master.json).fields;
    final remoteResponse =
        await api.dio.get<Map<String, dynamic>>('/profile-sets');
    final remoteItems = remoteResponse.data?['items'] as List? ?? const [];
    final remoteByClientId = {
      for (final raw in remoteItems)
        (raw as Map)['clientId'] as String: Map<String, dynamic>.from(raw),
    };
    final localRows = await database.select(database.sharingProfiles).get();
    for (final row in localRows.where((row) =>
        row.dirty ||
        !remoteByClientId.containsKey(row.id) ||
        remoteByClientId[row.id]?['migrationRequired'] == true)) {
      var sharing = SharingProfile.decode(row.json);
      try {
        final remoteVersion =
            (remoteByClientId[row.id]?['version'] as num?)?.toInt();
        if (remoteVersion != null && sharing.version <= remoteVersion) {
          sharing = await _setVersion(
            row,
            sharing,
            remoteVersion + 1,
          );
        }
        final view = <String, dynamic>{
          'fields': {
            for (final entry in fields.entries)
              if (sharing.visibleFields.contains(entry.key))
                entry.key: entry.value
          }
        };
        try {
          await _put(row.id, sharing.version, view);
        } on DioException catch (error) {
          if (!_isVersionConflict(error)) rethrow;
          final remote = await api.dio
              .get<Map<String, dynamic>>('/profile-sets/${row.id}');
          final serverVersion = (remote.data?['version'] as num?)?.toInt() ?? 0;
          sharing = await _setVersion(
            row,
            sharing,
            serverVersion >= sharing.version
                ? serverVersion + 1
                : sharing.version + 1,
          );
          await _put(row.id, sharing.version, view);
        }
        await database.markProfileSynced(row.id);
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          ProfileSyncException(sharing.name, error),
          stackTrace,
        );
      }
    }
  }

  Future<SharingProfile> _setVersion(
    db.SharingProfileRow row,
    SharingProfile sharing,
    int version,
  ) async {
    final updated = sharing.copyWith(version: version);
    await database.saveSharingProfile(
      id: row.id,
      json: updated.encode(),
      keyBase64: row.keyBase64,
      version: version,
    );
    return updated;
  }

  Future<void> _put(
    String id,
    int version,
    Map<String, dynamic> data,
  ) =>
      api.dio.put<void>('/profile-sets/$id', data: {
        'version': version,
        'data': data,
      });

  bool _isVersionConflict(DioException error) {
    final raw = error.response?.data;
    final root = raw is Map ? raw : const {};
    final nested = root['error'];
    final body = nested is Map ? nested : root;
    return body['code'] == 'version_conflict';
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

  Future<void> dispose() => _localChanges.close();
}

class SharingProfileInUseException implements Exception {
  const SharingProfileInUseException(this.connectionCount);

  final int connectionCount;
}

class ProfileSyncException implements Exception {
  const ProfileSyncException(this.profileName, this.cause);

  final String profileName;
  final Object cause;
}
