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

  void start() {
    unawaited(_syncIfEnabled());
    _subscription ??= Connectivity().onConnectivityChanged.listen((results) async {
      if (!results.contains(ConnectivityResult.none)) await _syncIfEnabled();
    });
  }
  Future<void> syncNow() async { await profiles.sync(); await connections.sync(); }
  Future<void> _syncIfEnabled() async {
    try {
      final setting = await (database.select(database.appSettings)..where((row) => row.key.equals('autoSync'))).getSingleOrNull();
      if (setting?.value != 'false') await syncNow();
    } catch (_) { /* Offline and authentication failures remain queued. */ }
  }
  Future<void> dispose() async => _subscription?.cancel();
}
