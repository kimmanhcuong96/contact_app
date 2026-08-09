import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/core/database/app_database.dart';
import 'package:nexbook/core/localization/app_localizations.dart';
import 'package:nexbook/core/network/api_client.dart';
import 'package:nexbook/core/network/localized_error.dart';
import 'package:nexbook/core/security/crypto_service.dart';
import 'package:nexbook/repositories/profile_repository.dart';
import 'package:nexbook/repositories/connection_repository.dart';
import 'package:flutter/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('uploads a missing sharing profile without a master profile', () async {
    const storage = FlutterSecureStorage();
    final crypto = CryptoService(storage);
    final api = ApiClient(storage, baseUrl: 'https://example.test/v1');
    final adapter = _RecordingAdapter();
    api.dio.httpClientAdapter = adapter;
    final key = await crypto.encodeKey(await crypto.newProfileKey());
    await database.saveSharingProfile(
      id: 'b87f598f-a41a-4b04-aa48-bf6b2310d024',
      json: jsonEncode({
        'id': 'b87f598f-a41a-4b04-aa48-bf6b2310d024',
        'name': 'Public',
        'visibleFields': ['fullName'],
        'version': 1,
      }),
      keyBase64: key,
      version: 1,
      dirty: false,
    );

    await ProfileRepository(database, api, crypto).sync();

    expect(adapter.requests.map((request) => request.path), [
      '/profile-sets',
      '/profile-sets/b87f598f-a41a-4b04-aa48-bf6b2310d024',
    ]);
    final upload = adapter.requests.last.data as Map<String, dynamic>;
    expect(upload['version'], 1);
    expect(upload['encryptedBlob'], containsPair('algorithm', 'AES-256-GCM'));
    expect((await database.select(database.sharingProfiles).getSingle()).dirty,
        isFalse);
  });

  test('does not delete a sharing profile assigned to a contact', () async {
    const storage = FlutterSecureStorage();
    final api = ApiClient(storage, baseUrl: 'https://example.test/v1');
    final profileId = 'b87f598f-a41a-4b04-aa48-bf6b2310d024';
    await database.into(database.connectedProfiles).insert(
          ConnectedProfilesCompanion.insert(
            connectionId: 'connection-id',
            peerUserId: 'peer-id',
            assignedProfileId: Value(profileId),
            status: 'connected',
            direction: 'outgoing',
            updatedAt: DateTime(2026),
          ),
        );

    await expectLater(
      ProfileRepository(database, api, CryptoService(storage))
          .deleteSharing(profileId),
      throwsA(isA<SharingProfileInUseException>()),
    );
  });

  test('recovers a dirty profile when the server already has its version',
      () async {
    const storage = FlutterSecureStorage();
    final crypto = CryptoService(storage);
    final api = ApiClient(storage, baseUrl: 'https://example.test/v1');
    final adapter = _ProfileVersionAdapter();
    api.dio.httpClientAdapter = adapter;
    const profileId = 'b87f598f-a41a-4b04-aa48-bf6b2310d024';
    final key = await crypto.encodeKey(await crypto.newProfileKey());
    await database.saveSharingProfile(
      id: profileId,
      json: jsonEncode({
        'id': profileId,
        'name': 'Friends',
        'visibleFields': ['fullName'],
        'version': 2,
      }),
      keyBase64: key,
      version: 2,
    );

    await ProfileRepository(database, api, crypto).sync();

    expect(adapter.uploadedVersions, [3]);
    final saved = await database.select(database.sharingProfiles).getSingle();
    expect(saved.version, 3);
    expect(jsonDecode(saved.json)['version'], 3);
    expect(saved.dirty, isFalse);
  });

  test('describes profile sync errors with profile context', () {
    final message = localizedError(
      AppLocalizations(const Locale('vi')),
      ProfileSyncException(
        'Bạn bè',
        DioException(
          requestOptions: RequestOptions(path: '/profile-sets/id'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    expect(message, contains('Bạn bè'));
    expect(message, contains('NexBook'));
  });

  test('keeps syncing when one connected profile cannot be decrypted',
      () async {
    const storage = FlutterSecureStorage();
    final crypto = CryptoService(storage);
    final api = ApiClient(storage, baseUrl: 'https://example.test/v1');
    api.dio.httpClientAdapter = _ConnectionAdapter();
    final profiles = ProfileRepository(database, api, crypto);

    await ConnectionRepository(database, api, crypto, profiles).sync();

    final contact =
        await database.select(database.connectedProfiles).getSingle();
    expect(contact.peerUsername, 'peer.user');
    expect(jsonDecode(contact.profileJson!)['error'], 'decryption_failed');
  });

  test('repairs a legacy queued assignment that has no peer user id', () async {
    const storage = FlutterSecureStorage();
    final crypto = CryptoService(storage);
    final api = ApiClient(storage, baseUrl: 'https://example.test/v1');
    final publicKey = await crypto.publicIdentityBase64();
    final adapter = _LegacyQueueAdapter(publicKey);
    api.dio.httpClientAdapter = adapter;
    final key = await crypto.encodeKey(await crypto.newProfileKey());
    await database.saveSharingProfile(
      id: 'profile-id',
      json: jsonEncode({
        'id': 'profile-id',
        'name': 'Friends',
        'visibleFields': ['fullName'],
        'version': 1,
      }),
      keyBase64: key,
      version: 1,
      dirty: false,
    );
    await database.into(database.connectedProfiles).insert(
          ConnectedProfilesCompanion.insert(
            connectionId: 'connection-id',
            peerUserId: 'peer-id',
            assignedProfileId: const Value('profile-id'),
            status: 'connected',
            direction: 'outgoing',
            updatedAt: DateTime(2026),
          ),
        );
    await database.enqueueConnectionAction(
      id: 'legacy-action',
      operation: 'assign',
      connectionId: 'connection-id',
      profileSetId: 'profile-id',
    );

    final profiles = ProfileRepository(database, api, crypto);
    await ConnectionRepository(database, api, crypto, profiles).sync();

    expect(await database.pendingConnectionQueue(), isEmpty);
    expect(adapter.assignedPeerKeyRequests, 1);
  });

  test('discards an unrecoverable queued action and does not fail again',
      () async {
    const storage = FlutterSecureStorage();
    final crypto = CryptoService(storage);
    final api = ApiClient(storage, baseUrl: 'https://example.test/v1');
    api.dio.httpClientAdapter = _LegacyQueueAdapter('unused');
    await database.enqueueConnectionAction(
      id: 'stale-action',
      operation: 'assign',
      connectionId: 'missing-connection',
      peerUserId: 'peer-id',
      profileSetId: 'deleted-profile',
    );
    final profiles = ProfileRepository(database, api, crypto);
    final connections = ConnectionRepository(database, api, crypto, profiles);

    await expectLater(
      connections.sync(),
      throwsA(isA<PendingConnectionActionException>()),
    );
    expect(await database.pendingConnectionQueue(), isEmpty);
    await expectLater(connections.sync(), completes);
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = options.method == 'GET' ? '{"items":[]}' : '{}';
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ProfileVersionAdapter implements HttpClientAdapter {
  final uploadedVersions = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode({
          'items': [
            {
              'clientId': 'b87f598f-a41a-4b04-aa48-bf6b2310d024',
              'version': 2,
            }
          ]
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    uploadedVersions.add((options.data as Map)['version'] as int);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ConnectionAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'items': [
          {
            'id': 'connection-id',
            'peerUserId': 'peer-id',
            'peerUsername': 'peer.user',
            'assignedProfileClientId': null,
            'status': 'connected',
            'direction': 'incoming',
            'keyEnvelope': {
              'ephemeralPublicKey': 'invalid',
              'nonce': 'invalid',
              'ciphertext': 'invalid',
            },
            'profile': {
              'version': 1,
              'encryptedBlob': {
                'algorithm': 'AES-256-GCM',
                'nonce': 'invalid',
                'ciphertext': 'invalid',
              },
            },
            'updatedAt': '2026-08-09T00:00:00.000Z',
          }
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _LegacyQueueAdapter implements HttpClientAdapter {
  _LegacyQueueAdapter(this.publicKey);

  final String publicKey;
  int assignedPeerKeyRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object body = <String, dynamic>{};
    if (options.path == '/users/peer-id/key') {
      assignedPeerKeyRequests++;
      body = {'userId': 'peer-id', 'publicKey': publicKey};
    } else if (options.method == 'GET' && options.path == '/connections') {
      body = {'items': <Object>[]};
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
