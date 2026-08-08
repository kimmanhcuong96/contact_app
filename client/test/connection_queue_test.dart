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
}
