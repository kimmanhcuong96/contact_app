import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/core/database/app_database.dart';
import 'package:nexbook/core/network/api_client.dart';
import 'package:nexbook/core/security/crypto_service.dart';
import 'package:nexbook/repositories/profile_repository.dart';
import 'package:nexbook/repositories/connection_repository.dart';

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
