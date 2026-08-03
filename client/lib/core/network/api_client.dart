import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient(this._storage, {String? baseUrl})
      : dio = Dio(BaseOptions(baseUrl: baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8787/v1'), connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20))) {
    dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest, onError: _onError));
  }

  final Dio dio;
  final FlutterSecureStorage _storage;
  Completer<void>? _refreshing;

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    if (error.response?.statusCode != 401 || error.requestOptions.extra['retried'] == true || error.requestOptions.path.contains('/auth/refresh')) return handler.next(error);
    try {
      await _refresh();
      final request = error.requestOptions;
      request.extra['retried'] = true;
      request.headers['Authorization'] = 'Bearer ${await _storage.read(key: 'access_token')}';
      handler.resolve(await dio.fetch<dynamic>(request));
    } catch (_) { handler.next(error); }
  }

  Future<void> _refresh() async {
    if (_refreshing != null) return _refreshing!.future;
    _refreshing = Completer<void>();
    try {
      final token = await _storage.read(key: 'refresh_token');
      if (token == null) throw StateError('No refresh token');
      final response = await Dio(dio.options).post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': token});
      await saveTokens(response.data!);
      _refreshing!.complete();
    } catch (error, stack) {
      await clearTokens();
      _refreshing!.completeError(error, stack);
      rethrow;
    } finally { _refreshing = null; }
  }

  Future<void> saveTokens(Map<String, dynamic> value) async {
    await _storage.write(key: 'access_token', value: value['accessToken'] as String);
    await _storage.write(key: 'refresh_token', value: value['refreshToken'] as String);
  }
  Future<void> clearTokens() async { await _storage.delete(key: 'access_token'); await _storage.delete(key: 'refresh_token'); }
  Future<bool> get hasSession async => await _storage.read(key: 'refresh_token') != null;
}

