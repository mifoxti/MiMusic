import 'package:flutter/material.dart';

/// Доступ к вложенному [Navigator] в [MainShell] (контент вкладок).
/// Маршруты из оверлея полного плеера должны пушиться сюда — тогда видны мини-плеер и bottom bar.
abstract final class ShellNavigatorHost {
  static GlobalKey<NavigatorState>? _key;

  static void register(GlobalKey<NavigatorState> key) {
    _key = key;
  }

  static void unregister() {
    _key = null;
  }

  /// Добавляет маршрут в стек shell. Возвращает `false`, если ключ ещё не зарегистрирован.
  static bool push(Route<void> route) {
    final state = _key?.currentState;
    if (state == null) return false;
    state.push(route);
    return true;
  }
}
