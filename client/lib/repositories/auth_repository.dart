import '../core/network/api_client.dart';
import '../core/security/crypto_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  AuthRepository(this.api, this.crypto);
  final ApiClient api;
  final CryptoService crypto;

  Future<Map<String, dynamic>> register(String email, String password) async =>
      (await api.dio.post<Map<String, dynamic>>('/auth/register',
              data: {'email': email, 'password': password}))
          .data!;
  Future<void> verifyEmail(String token) async {
    await api.dio.post<void>('/auth/verify-email', data: {'token': token});
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

  Future<void> login(String email, String password) async {
    final response = await api.dio.post<Map<String, dynamic>>('/auth/login',
        data: {'email': email, 'password': password});
    await api.saveTokens(response.data!);
    await api.dio.put<void>('/me/key',
        data: {'publicKey': await crypto.publicIdentityBase64()});
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
