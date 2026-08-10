import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../repositories/connection_repository.dart';
import '../../repositories/profile_repository.dart';
import '../database/app_database.dart';

class SyncService {
  SyncService(
    this.profiles,
    this.connections,
    this.database, {
    this.changeDebounce = const Duration(milliseconds: 150),
  });
  final ProfileRepository profiles;
  final ConnectionRepository connections;
  final AppDatabase database;
  final Duration changeDebounce;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  StreamSubscription<void>? _profileChangesSubscription;
  final _statuses = StreamController<SyncStatus>.broadcast();
  Future<void>? _activeSync;
  Timer? _changeTimer;
  bool _disposed = false;

  Stream<SyncStatus> get statuses => _statuses.stream;

  void start({bool syncOnStart = true, bool monitorConnectivity = true}) {
    if (syncOnStart) unawaited(_syncIfEnabled());
    _profileChangesSubscription ??=
        profiles.localChanges.listen((_) => requestAutomaticSync());
    if (monitorConnectivity) {
      _subscription ??=
          Connectivity().onConnectivityChanged.listen((results) async {
        if (!results.contains(ConnectivityResult.none)) await _syncIfEnabled();
      });
    }
  }

  void requestAutomaticSync() {
    if (_disposed) return;
    _changeTimer?.cancel();
    _changeTimer = Timer(changeDebounce, () => unawaited(_syncAfterChange()));
  }

  Future<void> syncNow() {
    final active = _activeSync;
    if (active != null) return active;
    final future = _runSync();
    _activeSync = future;
    return future.whenComplete(() {
      if (identical(_activeSync, future)) _activeSync = null;
    });
  }

  Future<void> _runSync() async {
    _statuses.add(const SyncStatus.syncing());
    try {
      try {
        await profiles.sync();
      } catch (error, stackTrace) {
        if (error is ProfileSyncException) rethrow;
        Error.throwWithStackTrace(
          SyncOperationException(SyncOperation.profiles, error),
          stackTrace,
        );
      }
      try {
        await connections.sync();
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(
          SyncOperationException(SyncOperation.connections, error),
          stackTrace,
        );
      }
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

  Future<void> _syncAfterChange() async {
    final active = _activeSync;
    if (active != null) {
      try {
        await active;
      } catch (_) {
        // Dirty local rows remain queued for the follow-up attempt.
      }
    }
    await _syncIfEnabled();
  }

  Future<void> dispose() async {
    _disposed = true;
    _changeTimer?.cancel();
    await _subscription?.cancel();
    await _profileChangesSubscription?.cancel();
    await _statuses.close();
  }
}

enum SyncOperation { profiles, connections }

class SyncOperationException implements Exception {
  const SyncOperationException(this.operation, this.cause);

  final SyncOperation operation;
  final Object cause;
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
