import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../repositories/connection_repository.dart';
import '../../repositories/profile_repository.dart';
import '../database/app_database.dart';

class SyncService {
  SyncService(this.profiles, this.connections, this.database);
  final ProfileRepository profiles;
  final ConnectionRepository connections;
  final AppDatabase database;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final _statuses = StreamController<SyncStatus>.broadcast();

  Stream<SyncStatus> get statuses => _statuses.stream;

  void start() {
    unawaited(_syncIfEnabled());
    _subscription ??=
        Connectivity().onConnectivityChanged.listen((results) async {
      if (!results.contains(ConnectivityResult.none)) await _syncIfEnabled();
    });
  }

  Future<void> syncNow() async {
    _statuses.add(const SyncStatus.syncing());
    try {
      await profiles.sync();
      await connections.sync();
      _statuses.add(const SyncStatus.success());
    } catch (error, stackTrace) {
      _statuses.add(SyncStatus.failure(error));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _syncIfEnabled() async {
    try {
      final setting = await (database.select(database.appSettings)
            ..where((row) => row.key.equals('autoSync')))
          .getSingleOrNull();
      if (setting?.value != 'false') await syncNow();
    } catch (_) {
      // syncNow records the failure while durable local queues remain pending.
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _statuses.close();
  }
}

class SyncStatus {
  const SyncStatus._({required this.isSyncing, this.error});

  const SyncStatus.syncing() : this._(isSyncing: true);
  const SyncStatus.success() : this._(isSyncing: false);
  const SyncStatus.failure(Object error)
      : this._(isSyncing: false, error: error);

  final bool isSyncing;
  final Object? error;
}
