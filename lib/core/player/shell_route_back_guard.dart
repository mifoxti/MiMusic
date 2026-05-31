import 'package:flutter/material.dart';

import 'full_player_visibility.dart';
import 'player_dock_host.dart';

/// Обёртка маршрута вложенного [Navigator] в shell: пока открыт полный плеер,
/// системное «назад» сворачивает док, а не удаляет этот маршрут со стека.
class ShellRouteBackGuard extends StatelessWidget {
  const ShellRouteBackGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: FullPlayerVisibility.open,
      builder: (context, playerFullOpen, _) {
        // Пока полный плеер открыт, системное «назад» не должно снимать маршрут (настройки и т.д.),
        // а только сворачивать док — иначе `canPop: true` из-за `Navigator.canPop()` отдаёт pop в стек.
        // Явный `Navigator.pop` из AppBar по-прежнему закрывает экран (не считается «scoped pop»).
        return PopScope(
          canPop: !playerFullOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (playerFullOpen) {
              PlayerDockHost.collapse();
            }
          },
          child: child,
        );
      },
    );
  }
}

/// [MaterialPageRoute] с [ShellRouteBackGuard] для маршрутов shell-навигатора.
class ShellMaterialPageRoute<T> extends MaterialPageRoute<T> {
  ShellMaterialPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
    bool opaque = true,
  })  : _opaque = opaque,
        super(
          builder: (context) => ShellRouteBackGuard(child: builder(context)),
        );

  final bool _opaque;

  @override
  bool get opaque => _opaque;

  /// Экран настроек поверх вкладок: прозрачный низ, чтобы стекло мини-плеера и
  /// нижней навигации размывало контент вкладки, а не градиент настроек.
  static ShellMaterialPageRoute<T> settingsOverlay<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return ShellMaterialPageRoute<T>(
      builder: builder,
      settings: settings,
      opaque: false,
    );
  }
}
