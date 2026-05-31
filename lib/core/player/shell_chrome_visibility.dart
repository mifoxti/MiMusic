import 'package:flutter/foundation.dart';

/// Прозрачный вид нижнего chrome (мини-плеер + навигация) поверх экранов настроек.
class ShellChromeVisibility {
  ShellChromeVisibility._();

  static final ValueNotifier<bool> seeThroughOverlay = ValueNotifier(false);
}

/// Имена маршрутов shell-навигатора для экранов настроек.
abstract final class ShellRouteNames {
  static const String settings = 'settings';

  static bool isSettingsRoute(String? name) {
    if (name == null) return false;
    return name == settings || name.startsWith('$settings/');
  }
}
