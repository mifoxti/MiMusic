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
        // Пока полный плеер открыт, на корне вкладки «назад» сворачивает док.
        // Если поверх shell уже открыт маршрут (напр. настройка комнаты), его нужно
        // закрывать pop'ом — иначе canPop: false блокирует и системный back, и стрелку AppBar.
        final nav = Navigator.maybeOf(context);
        final canPopRoute = nav?.canPop() ?? false;
        return PopScope(
          canPop: !playerFullOpen || canPopRoute,
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
  }) : super(
          builder: (context) => ShellRouteBackGuard(child: builder(context)),
        );
}
