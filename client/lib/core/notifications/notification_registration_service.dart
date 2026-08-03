import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

class NotificationRegistrationService {
  NotificationRegistrationService(this.api);
  final ApiClient api;
  StreamSubscription<String>? _subscription;

  Future<void> start() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken(vapidKey: const String.fromEnvironment('FCM_VAPID_KEY'));
      if (token != null) await _register(token);
      _subscription = messaging.onTokenRefresh.listen(_register);
    } catch (_) {
      // Firebase configuration is optional in local/offline builds.
    }
  }

  Future<void> _register(String token) async {
    final platform = kIsWeb ? 'web' : switch (defaultTargetPlatform) { TargetPlatform.iOS => 'ios', _ => 'android' };
    await api.dio.post<void>('/devices', data: {'token': token, 'platform': platform});
  }
  Future<void> dispose() async => _subscription?.cancel();
}
