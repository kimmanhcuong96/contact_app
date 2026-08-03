import '../core/database/app_database.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../core/network/api_client.dart';
import '../core/security/crypto_service.dart';
import '../models/encryption_models.dart';

class ConnectionRepository {
  ConnectionRepository(this.database, this.api, this.crypto);
  final AppDatabase database;
  final ApiClient api;
  final CryptoService crypto;

  Stream<List<ConnectedProfileRow>> watchConnections() =>
      database.select(database.connectedProfiles).watch();

  Future<void> request(String peerUserId, SharingProfileRow sharing) async {
    final keyResponse =
        await api.dio.get<Map<String, dynamic>>('/users/$peerUserId/key');
    final wrapped = await crypto.wrapKey(crypto.decodeKey(sharing.keyBase64),
        keyResponse.data!['publicKey'] as String);
    await api.dio.post<void>('/connections', data: {
      'peerUserId': peerUserId,
      'profileSetId': sharing.id,
      'keyEnvelope': wrapped.toJson()
    });
    await sync();
  }

  Future<void> act(String connectionId, String action,
      {SharingProfileRow? sharing, String? peerUserId}) async {
    Map<String, dynamic>? envelope;
    if (sharing != null && peerUserId != null) {
      final keyResponse =
          await api.dio.get<Map<String, dynamic>>('/users/$peerUserId/key');
      envelope = (await crypto.wrapKey(crypto.decodeKey(sharing.keyBase64),
              keyResponse.data!['publicKey'] as String))
          .toJson();
    }
    await api.dio.put<void>('/connections/$connectionId', data: {
      'action': action,
      if (sharing != null) 'profileSetId': sharing.id,
      if (envelope != null) 'keyEnvelope': envelope
    });
    await sync();
  }

  Future<void> delete(String id) async {
    await api.dio.delete<void>('/connections/$id');
    await sync();
  }

  Future<void> sync() async {
    final response = await api.dio.get<Map<String, dynamic>>('/connections');
    final items = response.data!['items'] as List;
    final seen = <String>{};
    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw as Map);
      seen.add(item['id'] as String);
      String? profileJson;
      final profile = item['profile'] as Map?;
      final keyEnvelope = item['keyEnvelope'] as Map?;
      if (profile != null && keyEnvelope != null) {
        final key = await crypto.unwrapKey(WrappedKeyEnvelope.fromJson(
            Map<String, dynamic>.from(keyEnvelope)));
        final clear = await crypto.decryptJson(
            EncryptedEnvelope.fromJson(
                Map<String, dynamic>.from(profile['encryptedBlob'] as Map)),
            key);
        profileJson = jsonEncode(clear);
      }
      await database
          .into(database.connectedProfiles)
          .insertOnConflictUpdate(ConnectedProfilesCompanion.insert(
            connectionId: item['id'] as String,
            peerUserId: item['peerUserId'] as String,
            status: item['status'] as String,
            direction: item['direction'] as String,
            profileJson: Value(profileJson),
            version: Value(profile?['version'] as int?),
            updatedAt: DateTime.tryParse(item['updatedAt'] as String? ?? '') ??
                DateTime.now(),
          ));
    }
    final local = await database.select(database.connectedProfiles).get();
    for (final row in local.where((row) => !seen.contains(row.connectionId))) {
      await (database.delete(database.connectedProfiles)
            ..where((table) => table.connectionId.equals(row.connectionId)))
          .go();
    }
  }
}
