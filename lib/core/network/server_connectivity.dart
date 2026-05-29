import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'api_config.dart';
import '../../presentation/widgets/glass_no_connection_sheet.dart';

/// Проверка доступности Ktor API и показ «нет связи с сервером».
class ServerConnectivity {
  ServerConnectivity._();

  static final ServerConnectivity instance = ServerConnectivity._();

  bool? _lastOnline;
  DateTime? _lastCheckedAt;

  bool get lastKnownOnline => _lastOnline ?? true;

  Future<bool> check({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < const Duration(seconds: 6)) {
      return _lastOnline ?? false;
    }
    _lastCheckedAt = now;
    try {
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final dio = Dio(
        BaseOptions(
          baseUrl: base,
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );
      await dio.get<dynamic>('/');
      _lastOnline = true;
    } catch (_) {
      _lastOnline = false;
    }
    return _lastOnline!;
  }

  static bool isNetworkDioError(DioException e) {
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
  }

  void markOffline() {
    _lastOnline = false;
    _lastCheckedAt = DateTime.now();
  }

  /// Показать sheet после текущего кадра (pull-to-refresh иначе «съедает» modal).
  void presentNoConnectionSheet(BuildContext context) {
    if (!context.mounted) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      unawaited(showGlassNoConnectionSheet(context));
    });
  }

  /// Явное действие пользователя: pull-to-refresh, смена вкладки, повторный запрос.
  Future<bool> guardUserNetworkAction(BuildContext context) async {
    if (await check(force: true)) return true;
    if (!context.mounted) return false;
    presentNoConnectionSheet(context);
    return false;
  }

  /// После неудачной загрузки — показать sheet, если это сетевая ошибка.
  Future<void> reportNetworkErrorIfOffline(BuildContext context, Object error) async {
    if (error is DioException && isNetworkDioError(error)) {
      markOffline();
      presentNoConnectionSheet(context);
    }
  }

  /// Перед сетевым действием: `false` — офлайн, sheet будет показан.
  Future<bool> ensureOnline(BuildContext context, {bool forceCheck = false}) async {
    if (await check(force: forceCheck)) return true;
    if (!context.mounted) return false;
    presentNoConnectionSheet(context);
    return false;
  }

  Future<T?> runOnline<T>(
    BuildContext context,
    Future<T> Function() action, {
    bool forceCheck = false,
    bool showOfflineSheet = true,
  }) async {
    if (!await check(force: forceCheck)) {
      if (showOfflineSheet && context.mounted) {
        presentNoConnectionSheet(context);
      }
      return null;
    }
    try {
      return await action();
    } on DioException catch (e) {
      if (isNetworkDioError(e)) {
        _lastOnline = false;
        if (showOfflineSheet && context.mounted) {
          presentNoConnectionSheet(context);
        }
        return null;
      }
      rethrow;
    }
  }
}
