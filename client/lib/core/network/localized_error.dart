import 'package:dio/dio.dart';
import '../localization/app_localizations.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/connection_repository.dart';
import '../sync/sync_service.dart';

String localizedError(AppLocalizations l10n, Object? error) {
  if (error is SharingProfileInUseException) {
    return l10n.t('error.profileInUse', {'count': error.connectionCount});
  }
  if (error is PendingConnectionActionException) {
    return l10n.t('error.pendingActionDiscarded');
  }
  if (error is ProfileSyncException) {
    return l10n.t('error.profileSyncFailed', {
      'name': error.profileName,
      'details': localizedError(l10n, error.cause),
    });
  }
  if (error is SyncOperationException) {
    return l10n.t(
      error.operation == SyncOperation.profiles
          ? 'error.profilesSyncFailed'
          : 'error.connectionsSyncFailed',
      {'details': localizedError(l10n, error.cause)},
    );
  }
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return l10n.t('error.timeout');
    }
    if (error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.unknown && error.response == null)) {
      return l10n.t('error.network');
    }

    final response = error.response;
    final raw = response?.data;
    final root = raw is Map ? raw : const {};
    final nested = root['error'];
    final body = nested is Map ? nested : root;
    final code = body['code']?.toString();
    final field = body['field']?.toString();

    if (code == 'validation_error') {
      return switch (field) {
        'password' => l10n.t('error.weakPassword'),
        'passwordConfirmation' => l10n.t('error.passwordMismatch'),
        'username' => l10n.t('error.invalidUsername'),
        'identifier' => l10n.t('error.usernameRequired'),
        'recoveryEmail' || 'email' => l10n.t('error.invalidEmail'),
        'currentPassword' => l10n.t('error.invalidPassword'),
        _ => l10n.t('error.generic'),
      };
    }

    final key = switch (code) {
      'username_exists' => 'error.usernameExists',
      'recovery_email_exists' => 'error.recoveryEmailExists',
      'invalid_credentials' => 'error.invalidCredentials',
      'invalid_password' => 'error.invalidPassword',
      'invalid_token' => 'error.invalidToken',
      'account_disabled' => 'error.accountDisabled',
      'unauthorized' ||
      'invalid_access_token' ||
      'invalid_refresh_token' =>
        'error.unauthorized',
      'connection_exists' => 'error.connectionExists',
      'invalid_peer' => 'error.invalidPeer',
      'invalid_profile_set' => 'error.invalidProfileSet',
      'invalid_state' || 'invalid_action' => 'error.invalidState',
      'forbidden' => 'error.forbidden',
      'version_conflict' => 'error.versionConflict',
      'rate_limited' => 'error.rateLimited',
      'not_found' => 'error.notFound',
      _ => null,
    };
    if (key != null) return l10n.t(key);
    if (response?.statusCode == 404) return l10n.t('error.notFound');
    if (response?.statusCode == 400 || response?.statusCode == 422) {
      return l10n.t('error.invalidData');
    }
    if ((response?.statusCode ?? 0) >= 500) return l10n.t('error.server');
  }
  if (error is FormatException || error is TypeError || error is StateError) {
    return l10n.t('error.localData');
  }
  return l10n.t('error.generic');
}
