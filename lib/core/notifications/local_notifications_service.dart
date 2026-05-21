import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'notification_intent.dart';
import '../settings/local_settings_repository.dart';

class LocalNotificationsService {
  LocalNotificationsService._();

  static final LocalNotificationsService instance = LocalNotificationsService._();

  static const AndroidNotificationChannel _friendRequestsChannel =
      AndroidNotificationChannel(
    'mimusic_friend_requests',
    'Заявки в друзья',
    description: 'Тестовые уведомления о заявках в друзья',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _soundPlayer = AudioPlayer();
  final StreamController<NotificationIntent> _intentController =
      StreamController<NotificationIntent>.broadcast();
  NotificationIntent? _pendingIntent;
  bool _initialized = false;

  Stream<NotificationIntent> get intents => _intentController.stream;
  NotificationIntent? takePendingIntent() {
    final out = _pendingIntent;
    _pendingIntent = null;
    return out;
  }

  /// Регистрирует platform implementation до [FlutterLocalNotificationsPlugin.initialize].
  /// Иначе на части устройств: LateInitializationError: Field '_instance' has not been initialized.
  void _ensurePlatformRegistered() {
    if (kIsWeb) return;
    try {
      if (Platform.isAndroid) {
        AndroidFlutterLocalNotificationsPlugin.registerWith();
      } else if (Platform.isIOS) {
        IOSFlutterLocalNotificationsPlugin.registerWith();
      }
    } catch (e, st) {
      debugPrint('[notifications] platform registerWith failed: $e\n$st');
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;

    try {
      _ensurePlatformRegistered();

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          _handleNotificationResponse(response);
        },
      );

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final launchResponse = launchDetails?.notificationResponse;
      if (launchResponse != null) {
        _handleNotificationResponse(launchResponse);
      }

      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_friendRequestsChannel);
      await androidPlugin?.requestNotificationsPermission();
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      _initialized = true;
    } catch (e, st) {
      if (e.toString().contains('LateInitializationError')) {
        debugPrint('[notifications] init LateInitializationError: $e\n$st');
        return;
      }
      debugPrint('[notifications] init failed: $e\n$st');
    }
  }

  Future<void> showFriendRequestNotification({
    required String fromUsername,
    String? fromAvatarUrl,
    String? fromAvatarAssetPath,
  }) async {
    final notificationsEnabled = await _notificationsEnabled();
    if (!notificationsEnabled) return;

    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    final avatarPath = await _resolveAvatarPath(
      avatarUrl: fromAvatarUrl,
      avatarAssetPath: fromAvatarAssetPath,
    );
    final avatarBitmap =
        avatarPath != null ? FilePathAndroidBitmap(avatarPath) : null;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _friendRequestsChannel.id,
        _friendRequestsChannel.name,
        channelDescription: _friendRequestsChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: avatarBitmap,
        styleInformation: avatarBitmap != null
            ? BigPictureStyleInformation(
                avatarBitmap,
                largeIcon: avatarBitmap,
                hideExpandedLargeIcon: false,
              )
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        attachments: avatarPath != null
            ? <DarwinNotificationAttachment>[
                DarwinNotificationAttachment(avatarPath),
              ]
            : null,
      ),
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Новая заявка в друзья',
      body: '@$fromUsername отправил(а) вам заявку',
      notificationDetails: details,
      payload: NotificationIntent(
        target: NotificationTarget.friendProfile,
        username: fromUsername,
        avatarUrl: fromAvatarUrl,
      ).toPayload(),
    );
    await _playInAppNotificationSound();
  }

  Future<void> showReleaseNotification({
    required String releaseTitle,
    String? releaseCoverUrl,
  }) async {
    final notificationsEnabled = await _notificationsEnabled();
    if (!notificationsEnabled) return;
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _friendRequestsChannel.id,
        _friendRequestsChannel.name,
        channelDescription: _friendRequestsChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Новый альбом',
      body: releaseTitle,
      notificationDetails: details,
      payload: NotificationIntent(
        target: NotificationTarget.release,
        releaseTitle: releaseTitle,
        releaseCoverUrl: releaseCoverUrl,
      ).toPayload(),
    );
  }

  Future<void> showColistenInviteNotification({
    required String fromUsername,
    required String roomId,
    String? fromAvatarUrl,
    String? fromAvatarAssetPath,
  }) async {
    final notificationsEnabled = await _notificationsEnabled();
    if (!notificationsEnabled) return;
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return;
    final avatarPath = await _resolveAvatarPath(
      avatarUrl: fromAvatarUrl,
      avatarAssetPath: fromAvatarAssetPath,
    );
    final avatarBitmap =
        avatarPath != null ? FilePathAndroidBitmap(avatarPath) : null;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _friendRequestsChannel.id,
        _friendRequestsChannel.name,
        channelDescription: _friendRequestsChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        largeIcon: avatarBitmap,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        attachments: avatarPath != null
            ? <DarwinNotificationAttachment>[
                DarwinNotificationAttachment(avatarPath),
              ]
            : null,
      ),
    );
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'Приглашение в совместное прослушивание',
      body: '@$fromUsername приглашает вас в комнату',
      notificationDetails: details,
      payload: NotificationIntent(
        target: NotificationTarget.colistenInvite,
        username: fromUsername,
        avatarUrl: fromAvatarUrl,
        roomId: roomId,
      ).toPayload(),
    );
  }

  Future<String?> _resolveAvatarPath({
    String? avatarUrl,
    String? avatarAssetPath,
  }) async {
    final downloaded = await _downloadAvatarToTempFile(avatarUrl);
    if (downloaded != null) return downloaded;
    final local = await _useLocalFileIfExists(avatarAssetPath);
    if (local != null) return local;
    return _copyAssetAvatarToTempFile(avatarAssetPath);
  }

  Future<String?> _downloadAvatarToTempFile(String? url) async {
    final raw = (url ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      final uri = Uri.parse(raw);
      if (!uri.hasScheme) return null;
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        client.close(force: true);
        return null;
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      client.close(force: true);
      final ext = _extensionFromPath(uri.path);
      final file = File(
        '${Directory.systemTemp.path}/mimusic_notify_avatar_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _copyAssetAvatarToTempFile(String? assetPath) async {
    final asset = (assetPath ?? '').trim();
    if (asset.isEmpty) return null;
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List();
      final ext = _extensionFromPath(asset);
      final file = File(
        '${Directory.systemTemp.path}/mimusic_notify_avatar_asset_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _useLocalFileIfExists(String? maybeFilePath) async {
    final path = (maybeFilePath ?? '').trim();
    if (path.isEmpty) return null;
    if (path.startsWith('assets/')) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        return file.path;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<bool> _notificationsEnabled() async {
    try {
      final settings = await LocalSettingsRepository().getSettings();
      return settings.notificationsEnabled;
    } catch (_) {
      return true;
    }
  }

  String _extensionFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (lower.endsWith('.webp')) return 'webp';
    return 'png';
  }

  Future<void> _playInAppNotificationSound() async {
    try {
      await _soundPlayer.setAsset('assets/notification/notification.mp3');
      await _soundPlayer.seek(Duration.zero);
      await _soundPlayer.play();
    } catch (_) {
      // В тестовом режиме молча пропускаем ошибку звука.
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final intent = NotificationIntent.fromPayload(response.payload);
    if (intent == null) return;
    if (_intentController.hasListener) {
      _intentController.add(intent);
    } else {
      _pendingIntent = intent;
    }
  }
}
