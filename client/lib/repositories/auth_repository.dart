import '../core/network/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;

  Future<void> register(String username, String recoveryEmail, String password,
      String passwordConfirmation) async {
    await api.dio.post<void>('/auth/register', data: {
      'username': username,
      'recoveryEmail': recoveryEmail,
      'password': password,
      'passwordConfirmation': passwordConfirmation,
    });
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async =>
      (await api.dio.post<Map<String, dynamic>>('/auth/forgot-password',
              data: {'email': email}))
          .data!;
  Future<void> resetPassword(String token, String password) async {
    await api.dio.post<void>('/auth/reset-password',
        data: {'token': token, 'password': password});
  }

  Future<void> changePassword(String currentPassword, String password) async {
    await api.dio.post<void>('/auth/change-password',
        data: {'currentPassword': currentPassword, 'password': password});
  }

  Future<Map<String, dynamic>> getAccount() async =>
      (await api.dio.get<Map<String, dynamic>>('/me')).data!;

  Future<void> updateRecoveryEmail(
      String recoveryEmail, String currentPassword) async {
    await api.dio.put<void>('/auth/recovery-email', data: {
      'recoveryEmail': recoveryEmail,
      'currentPassword': currentPassword,
    });
  }

  Future<void> login(String identifier, String password) async {
    final response = await api.dio.post<Map<String, dynamic>>('/auth/login',
        data: {'identifier': identifier, 'password': password});
    await _completeAuthentication(response.data!);
  }

  Future<void> _completeAuthentication(Map<String, dynamic> tokens) async {
    await api.saveTokens(tokens);
  }

  Future<void> logout() async {
    final refresh =
        await const FlutterSecureStorage().read(key: 'refresh_token');
    if (refresh != null) {
      try {
        await api.dio
            .post<void>('/auth/logout', data: {'refreshToken': refresh});
      } catch (_) {}
    }
    await api.clearTokens();
  }
}
