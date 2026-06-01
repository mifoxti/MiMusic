import 'dart:async' show unawaited;
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_session_store.dart';
import '../network/push_api.dart';
import 'local_notifications_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await LocalNotificationsService.instance.initialize();
  await _showFromRemoteMessage(message);
}

class PushRegistrationService {
  PushRegistrationService._();

  static final PushRegistrationService instance = PushRegistrationService._();

  bool _initialized = false;
  String? _lastRegisteredToken;

  Future<void> initialize() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((m) {
        unawaited(_routeOpenedMessage(m));
      });
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        unawaited(_routeOpenedMessage(initial));
      }
      messaging.onTokenRefresh.listen((t) => _registerIfLoggedIn(t));
      final token = await messaging.getToken();
      if (token != null) {
        await _registerIfLoggedIn(token);
      }
      _initialized = true;
      debugPrint('[push] FCM initialized');
    } catch (e, st) {
      debugPrint('[push] FCM init skipped (add google-services.json): $e\n$st');
    }
  }

  Future<void> syncTokenAfterLogin() async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerIfLoggedIn(token);
      }
    } catch (_) {}
  }

  Future<void> unregisterOnLogout() async {
    final token = _lastRegisteredToken;
    if (token == null || token.isEmpty) return;
    try {
      await PushApi().unregisterToken(token);
    } catch (_) {}
    _lastRegisteredToken = null;
  }

  Future<void> _registerIfLoggedIn(String token) async {
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty) return;
    if (_lastRegisteredToken == token) return;
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      await PushApi().registerToken(token, platform: platform);
      _lastRegisteredToken = token;
      debugPrint('[push] token registered …${token.substring(token.length - 8)}');
    } catch (e) {
      debugPrint('[push] register failed: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    await _showFromRemoteMessage(message);
  }

  Future<void> _routeOpenedMessage(RemoteMessage message) async {
    // При тапе по FCM с блоком notification ОС открывает приложение;
    // навигация — через LocalNotificationsService / MainShell intents.
  }
}

Future<void> _showFromRemoteMessage(RemoteMessage message) async {
  final n = message.notification;
  final data = message.data;
  final type = data['type'] ?? '';
  final title = n?.title ?? data['title'] ?? 'MiMusic';
  final body = n?.body ?? data['body'] ?? '';
  final imageUrl = n?.android?.imageUrl ?? n?.apple?.imageUrl ?? data['imageUrl'];

  if (type == 'colisten_invite') {
    final roomId = data['roomId'] ?? '';
    final nick = data['actorNickname'] ?? 'MiMusic';
    if (roomId.isEmpty) return;
    await LocalNotificationsService.instance.showColistenInviteNotification(
      fromUsername: nick,
      roomId: roomId,
    );
    return;
  }
  if (type == 'friend_request') {
    final nick = data['actorNickname'] ?? 'MiMusic';
    await LocalNotificationsService.instance.showFriendRequestNotification(
      fromUsername: nick,
    );
    return;
  }
  if (type == 'admin_message' || title.isNotEmpty || body.isNotEmpty) {
    await LocalNotificationsService.instance.showAdminMessageNotification(
      title: title,
      body: body,
      imageUrl: imageUrl,
    );
  }
}
