import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'database/app_database.dart';
import 'localization/app_localizations.dart';
import 'network/api_client.dart';
import 'security/crypto_service.dart';
import '../repositories/auth_repository.dart';
import '../repositories/connection_repository.dart';
import '../repositories/profile_repository.dart';
import '../models/master_profile.dart';
import '../models/sharing_profile.dart';
import 'sync/sync_service.dart';
import 'notifications/notification_registration_service.dart';

final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());
final databaseProvider = Provider((ref) {
  final value = AppDatabase();
  ref.onDispose(value.close);
  return value;
});
final apiClientProvider =
    Provider((ref) => ApiClient(ref.watch(secureStorageProvider)));
final cryptoProvider =
    Provider((ref) => CryptoService(ref.watch(secureStorageProvider)));
final authRepositoryProvider = Provider((ref) =>
    AuthRepository(ref.watch(apiClientProvider), ref.watch(cryptoProvider)));
final accountProvider = FutureProvider<Map<String, dynamic>>(
    (ref) => ref.watch(authRepositoryProvider).getAccount());
final profileRepositoryProvider = Provider((ref) => ProfileRepository(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
    ref.watch(cryptoProvider)));
final connectionRepositoryProvider = Provider((ref) => ConnectionRepository(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
    ref.watch(cryptoProvider),
    ref.watch(profileRepositoryProvider)));
final syncServiceProvider = Provider((ref) {
  final value = SyncService(ref.watch(profileRepositoryProvider),
      ref.watch(connectionRepositoryProvider), ref.watch(databaseProvider))
    ..start();
  ref.onDispose(value.dispose);
  return value;
});
final syncStatusProvider =
    StreamProvider((ref) => ref.watch(syncServiceProvider).statuses);
final notificationRegistrationProvider = Provider((ref) {
  final value = NotificationRegistrationService(ref.watch(apiClientProvider))
    ..start();
  ref.onDispose(value.dispose);
  return value;
});

final masterProfileProvider = StreamProvider<MasterProfile>(
    (ref) => ref.watch(profileRepositoryProvider).watchMaster());
final sharingProfilesProvider = StreamProvider<List<SharingProfile>>(
    (ref) => ref.watch(profileRepositoryProvider).watchSharing());
final connectionsProvider = StreamProvider(
    (ref) => ref.watch(connectionRepositoryProvider).watchConnections());
final themeModeProvider = FutureProvider<ThemeMode>((ref) async {
  final database = ref.watch(databaseProvider);
  final row = await (database.select(database.appSettings)
        ..where((item) => item.key.equals('theme')))
      .getSingleOrNull();
  return switch (row?.value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system
  };
});
final localeProvider = FutureProvider<Locale>((ref) async {
  final database = ref.watch(databaseProvider);
  final row = await (database.select(database.appSettings)
        ..where((item) => item.key.equals('language')))
      .getSingleOrNull();
  final savedCode = switch (row?.value) {
    'vi' || 'Vietnamese' || 'Tiếng Việt' => 'vi',
    'zh' || 'Chinese' || '中文' => 'zh',
    'ja' || 'Japanese' || '日本語' => 'ja',
    'en' || 'English' => 'en',
    _ => null,
  };
  if (savedCode != null) return Locale(savedCode);

  String? country;
  try {
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get<Map<String, dynamic>>('/locale');
    country = response.data?['country'] as String?;
  } catch (_) {
    // The device/browser locale is the offline fallback.
  }
  return detectDefaultLocale(
    WidgetsBinding.instance.platformDispatcher.locales,
    countryCode: country,
  );
});

class SessionController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(apiClientProvider).hasSession;
  Future<void> login(String identifier, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).login(identifier, password);
      await ref.read(profileRepositoryProvider).initializeDefaults();
      return true;
    });
  }

  Future<bool> register(String username, String recoveryEmail, String password,
      String passwordConfirmation) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .register(username, recoveryEmail, password, passwordConfirmation);
      return false;
    });
    return !state.hasError;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(false);
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionController, bool>(SessionController.new);
