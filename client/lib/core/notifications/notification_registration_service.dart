import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';

class NotificationRegistrationService {
  NotificationRegistrationService(this.api, {this.onDataChanged});
  final ApiClient api;
  final Future<void> Function()? onDataChanged;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  Future<void> start() async {
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      const vapidKey = String.fromEnvironment('FCM_VAPID_KEY');
      final token = await messaging.getToken(
          vapidKey: vapidKey.isEmpty ? null : vapidKey);
      if (token != null) await _register(token);
      _tokenSubscription = messaging.onTokenRefresh.listen(_register);
      _messageSubscription = FirebaseMessaging.onMessage.listen(_handleMessage);
      _openedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleMessage(initialMessage);
    } catch (_) {
      // Firebase configuration is optional in local/offline builds.
    }
  }

  void _handleMessage(RemoteMessage message) {
    if (!const {
      'profile_updated',
      'sharing_profile_changed',
      'connection_request',
      'connection_accepted',
      'connection_refreshed',
      'identity_key_changed',
      'key_refresh_requested',
    }.contains(message.data['event'])) {
      return;
    }
    final callback = onDataChanged;
    if (callback != null) unawaited(callback());
  }

  Future<void> _register(String token) async {
    final platform = kIsWeb
        ? 'web'
        : switch (defaultTargetPlatform) {
            TargetPlatform.iOS => 'ios',
            _ => 'android'
          };
    await api.dio
        .post<void>('/devices', data: {'token': token, 'platform': platform});
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
