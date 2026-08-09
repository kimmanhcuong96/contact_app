import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/network/api_client.dart';
import '../core/security/crypto_service.dart';
import '../models/encryption_models.dart';
import 'profile_repository.dart';

class ConnectionRepository {
  ConnectionRepository(this.database, this.api, this.crypto, this.profiles);

  final AppDatabase database;
  final ApiClient api;
  final CryptoService crypto;
  final ProfileRepository profiles;
  final _uuid = const Uuid();

  Stream<List<ConnectedProfileRow>> watchConnections() =>
      database.select(database.connectedProfiles).watch();

  Future<bool> request(String peerUserId, SharingProfileRow sharing) async {
    final existing = await (database.select(database.connectedProfiles)
          ..where((row) =>
              row.peerUserId.equals(peerUserId) &
              row.status.isIn(const ['connected', 'disabled'])))
        .getSingleOrNull();
    if (existing != null) {
      await act(
        existing.connectionId,
        'reconnect',
        sharing: sharing,
        peerUserId: peerUserId,
      );
      return true;
    }
    final actionId = _uuid.v4();
    await database.transaction(() async {
      await database.enqueueConnectionAction(
        id: actionId,
        operation: 'request',
        peerUserId: peerUserId,
        profileSetId: sharing.id,
      );
      await database.into(database.connectedProfiles).insertOnConflictUpdate(
            ConnectedProfilesCompanion.insert(
              connectionId: 'local:$actionId',
              peerUserId: peerUserId,
              assignedProfileId: Value(sharing.id),
              status: 'pending',
              direction: 'outgoing',
              updatedAt: DateTime.now(),
            ),
          );
    });
    await _flushAndPullWhenAvailable(syncProfiles: true);
    final refreshed = await (database.select(database.connectedProfiles)
          ..where((row) =>
              row.peerUserId.equals(peerUserId) &
              row.status.equals('connected')))
        .getSingleOrNull();
    return refreshed != null;
  }

  Future<void> act(
    String connectionId,
    String action, {
    SharingProfileRow? sharing,
    String? peerUserId,
  }) async {
    if (connectionId.startsWith('local:') && action == 'cancel') {
      await database.transaction(() async {
        if (peerUserId != null) await database.removePendingRequest(peerUserId);
        await _removeLocalConnection(connectionId);
      });
      return;
    }

    await database.transaction(() async {
      await database.enqueueConnectionAction(
        id: _uuid.v4(),
        operation: action,
        connectionId: connectionId,
        peerUserId: peerUserId,
        profileSetId: sharing?.id,
      );
      await _applyOptimisticAction(
        connectionId,
        action,
        assignedProfileId: sharing?.id,
      );
    });
    await _flushAndPullWhenAvailable(syncProfiles: sharing != null);
  }

  Future<void> actMany(
    List<ConnectedProfileRow> connections,
    String action, {
    SharingProfileRow? sharing,
  }) async {
    if (connections.isEmpty) return;
    await database.transaction(() async {
      for (final connection in connections) {
        await database.enqueueConnectionAction(
          id: _uuid.v4(),
          operation: action,
          connectionId: connection.connectionId,
          peerUserId: connection.peerUserId,
          profileSetId: sharing?.id,
        );
        await _applyOptimisticAction(
          connection.connectionId,
          action,
          assignedProfileId: sharing?.id,
        );
      }
    });
    await _flushAndPullWhenAvailable(syncProfiles: sharing != null);
  }

  Future<void> delete(String connectionId) async {
    if (connectionId.startsWith('local:')) {
      final row = await (database.select(database.connectedProfiles)
            ..where((item) => item.connectionId.equals(connectionId)))
          .getSingleOrNull();
      await database.transaction(() async {
        if (row != null) await database.removePendingRequest(row.peerUserId);
        await _removeLocalConnection(connectionId);
      });
      return;
    }
    await database.transaction(() async {
      await database.enqueueConnectionAction(
        id: _uuid.v4(),
        operation: 'delete',
        connectionId: connectionId,
      );
      await _removeLocalConnection(connectionId);
    });
    await _flushAndPullWhenAvailable();
  }

  Future<void> deleteMany(List<ConnectedProfileRow> connections) async {
    if (connections.isEmpty) return;
    await database.transaction(() async {
      for (final connection in connections) {
        await database.enqueueConnectionAction(
          id: _uuid.v4(),
          operation: 'delete',
          connectionId: connection.connectionId,
        );
        await _removeLocalConnection(connection.connectionId);
      }
    });
    await _flushAndPullWhenAvailable();
  }

  Future<void> flushPendingActions() async {
    final queue = await database.pendingConnectionQueue();
    for (final pending in queue) {
      try {
        await _send(pending);
        await database.removePendingConnectionAction(pending.id);
      } on DioException catch (error) {
        if (error.response != null) {
          await database.removePendingConnectionAction(pending.id);
          if (pending.operation == 'request') {
            await _removeLocalConnection('local:${pending.id}');
          }
        }
        rethrow;
      }
    }
  }

  Future<void> _send(PendingConnectionActionRow pending) async {
    if (pending.operation == 'request') {
      final sharing = await _sharingProfile(pending.profileSetId!);
      final envelope = await _keyEnvelope(sharing, pending.peerUserId!);
      await api.dio.post<void>('/connections', data: {
        'peerUserId': pending.peerUserId,
        'profileSetId': sharing.id,
        'keyEnvelope': envelope,
      });
      return;
    }
    if (pending.operation == 'delete') {
      await api.dio.delete<void>('/connections/${pending.connectionId}');
      return;
    }
    final sharing = pending.profileSetId == null
        ? null
        : await _sharingProfile(pending.profileSetId!);
    final envelope = sharing == null
        ? null
        : await _keyEnvelope(sharing, pending.peerUserId!);
    await api.dio.put<void>(
      '/connections/${pending.connectionId}',
      data: {
        'action': pending.operation,
        if (sharing != null) 'profileSetId': sharing.id,
        if (envelope != null) 'keyEnvelope': envelope,
      },
    );
  }

  Future<void> sync() async {
    await flushPendingActions();
    await _pull();
  }

  Future<void> _pull() async {
    final response = await api.dio.get<Map<String, dynamic>>('/connections');
    final items = response.data!['items'] as List;
    final seen = <String>{};
    for (final raw in items) {
      final item = Map<String, dynamic>.from(raw as Map);
      final connectionId = item['id'] as String;
      final peerUserId = item['peerUserId'] as String;
      seen.add(connectionId);
      String? profileJson;
      final profile = item['profile'] as Map?;
      final keyEnvelope = item['keyEnvelope'] as Map?;
      if (profile != null && keyEnvelope != null) {
        try {
          final key = await crypto.unwrapKey(WrappedKeyEnvelope.fromJson(
              Map<String, dynamic>.from(keyEnvelope)));
          final clear = await crypto.decryptJson(
            EncryptedEnvelope.fromJson(
                Map<String, dynamic>.from(profile['encryptedBlob'] as Map)),
            key,
          );
          profileJson = jsonEncode(clear);
        } catch (error, stackTrace) {
          debugPrint(
              'Unable to decrypt profile for connection $connectionId: $error\n$stackTrace');
          profileJson = jsonEncode({
            'fields': <String, String>{},
            'error': 'decryption_failed',
          });
        }
      }
      await database.into(database.connectedProfiles).insertOnConflictUpdate(
            ConnectedProfilesCompanion.insert(
              connectionId: connectionId,
              peerUserId: peerUserId,
              peerUsername: Value(item['peerUsername'] as String?),
              assignedProfileId:
                  Value(item['assignedProfileClientId'] as String?),
              status: item['status'] as String,
              direction: item['direction'] as String,
              profileJson: Value(profileJson),
              version: Value(profile?['version'] as int?),
              updatedAt:
                  DateTime.tryParse(item['updatedAt'] as String? ?? '') ??
                      DateTime.now(),
            ),
          );
      await (database.delete(database.connectedProfiles)
            ..where((row) =>
                row.connectionId.like('local:%') &
                row.peerUserId.equals(peerUserId)))
          .go();
    }
    final local = await database.select(database.connectedProfiles).get();
    for (final row in local.where((row) =>
        !row.connectionId.startsWith('local:') &&
        !seen.contains(row.connectionId))) {
      await _removeLocalConnection(row.connectionId);
    }
  }

  Future<SharingProfileRow> _sharingProfile(String id) =>
      (database.select(database.sharingProfiles)
            ..where((row) => row.id.equals(id)))
          .getSingle();

  Future<Map<String, dynamic>> _keyEnvelope(
      SharingProfileRow sharing, String peerUserId) async {
    final keyResponse =
        await api.dio.get<Map<String, dynamic>>('/users/$peerUserId/key');
    return (await crypto.wrapKey(
      crypto.decodeKey(sharing.keyBase64),
      keyResponse.data!['publicKey'] as String,
    ))
        .toJson();
  }

  Future<void> _applyOptimisticAction(
    String connectionId,
    String action, {
    String? assignedProfileId,
  }) async {
    if (const {'reject', 'cancel', 'delete'}.contains(action)) {
      await _removeLocalConnection(connectionId);
      return;
    }
    final status = switch (action) {
      'accept' || 'enable' || 'reconnect' => 'connected',
      'disable' => 'disabled',
      _ => null,
    };
    if (status != null || assignedProfileId != null) {
      await (database.update(database.connectedProfiles)
            ..where((row) => row.connectionId.equals(connectionId)))
          .write(ConnectedProfilesCompanion(
        status: status == null ? const Value.absent() : Value(status),
        assignedProfileId: assignedProfileId == null
            ? const Value.absent()
            : Value(assignedProfileId),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  Future<void> _removeLocalConnection(String connectionId) =>
      (database.delete(database.connectedProfiles)
            ..where((row) => row.connectionId.equals(connectionId)))
          .go();

  Future<void> _flushAndPullWhenAvailable({bool syncProfiles = false}) async {
    try {
      if (syncProfiles) await profiles.sync();
      await sync();
    } on DioException catch (error) {
      if (!_isNetworkFailure(error)) {
        try {
          await _pull();
        } catch (_) {
          // Preserve the original API error shown to the user.
        }
        rethrow;
      }
    }
  }

  bool _isNetworkFailure(DioException error) =>
      error.response == null &&
      const {
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      }.contains(error.type);
}
