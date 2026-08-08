import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/core/database/app_database.dart';
import 'package:nexbook/core/network/api_client.dart';
import 'package:nexbook/core/security/crypto_service.dart';
import 'package:nexbook/repositories/profile_repository.dart';

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
