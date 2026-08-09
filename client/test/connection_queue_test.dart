import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexbook/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('persists and removes connection actions in queue order', () async {
    await database.enqueueConnectionAction(
      id: 'first',
      operation: 'request',
      peerUserId: 'peer-1',
      profileSetId: 'profile-1',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await database.enqueueConnectionAction(
      id: 'second',
      operation: 'disable',
      connectionId: 'connection-1',
    );

    final queue = await database.pendingConnectionQueue();
    expect(queue.map((item) => item.id), ['first', 'second']);
    expect(queue.first.peerUserId, 'peer-1');
    expect(queue.first.profileSetId, 'profile-1');

    await database.removePendingConnectionAction('first');
    expect(
      (await database.pendingConnectionQueue()).single.id,
      'second',
    );
  });

  test('clears user data when a different account signs in', () async {
    await database.scopeUserData('old-user');
    await database.enqueueConnectionAction(
      id: 'stale-action',
      operation: 'request',
      peerUserId: 'old-peer',
      profileSetId: 'old-profile',
    );
    await database.into(database.connectedProfiles).insert(
          ConnectedProfilesCompanion.insert(
            connectionId: 'old-connection',
            peerUserId: 'old-peer',
            status: 'connected',
            direction: 'outgoing',
            updatedAt: DateTime(2026),
          ),
        );
    await database.into(database.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: 'theme', value: 'dark'),
        );

    await database.scopeUserData('new-user');

    expect(await database.select(database.connectedProfiles).get(), isEmpty);
    expect(await database.pendingConnectionQueue(), isEmpty);
    expect(
      (await (database.select(database.appSettings)
                ..where((row) => row.key.equals('localDataOwner')))
              .getSingle())
          .value,
      'new-user',
    );
    expect(
      (await (database.select(database.appSettings)
                ..where((row) => row.key.equals('theme')))
              .getSingle())
          .value,
      'dark',
    );
  });

  test('queues one profile-key refresh for a changed peer identity', () async {
    expect(
      await database.queuePeerKeyRefresh(
        connectionId: 'connection-id',
        peerUserId: 'peer-id',
        profileSetId: 'profile-id',
        publicKey: 'new-public-key',
      ),
      isTrue,
    );
    expect(
      await database.queuePeerKeyRefresh(
        connectionId: 'connection-id',
        peerUserId: 'peer-id',
        profileSetId: 'profile-id',
        publicKey: 'new-public-key',
      ),
      isFalse,
    );

    final pending = await database.pendingConnectionQueue();
    expect(pending, hasLength(1));
    expect(pending.single.operation, 'assign');
    expect(pending.single.profileSetId, 'profile-id');
  });
}
