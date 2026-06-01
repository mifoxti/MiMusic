import 'package:flutter/material.dart';

import '../../presentation/widgets/glass_bottom_menu_sheet.dart';
import 'full_player_visibility.dart';
import 'player_dock_host.dart';
import 'shell_chrome_visibility.dart';

/// Обёртка маршрута вложенного [Navigator] в shell: пока открыт полный плеер
/// или стеклянный modal/sheet, системное «назад» закрывает их, а не снимает маршрут.
class ShellRouteBackGuard extends StatelessWidget {
  const ShellRouteBackGuard({super.key, required this.child});

  final Widget child;

  static void _popOpenGlassModal(BuildContext context) {
    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) {
      root.pop();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        FullPlayerVisibility.open,
        GlassModalOverlay.depth,
      ]),
      builder: (context, _) {
        final playerFullOpen = FullPlayerVisibility.open.value;
        final glassModalOpen = GlassModalOverlay.depth.value > 0;
        return PopScope(
          canPop: !playerFullOpen && !glassModalOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (glassModalOpen) {
              _popOpenGlassModal(context);
              return;
            }
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

  /// Маршрут экрана настроек (и вложенных): [RouteSettings.name] для [ShellChromeVisibility].
  ///
  /// Маршрут остаётся opaque: иначе прозрачный [Material] перехватывает жесты
  /// (кнопка настроек в профиле и тапы по списку перестают работать).
  static ShellMaterialPageRoute<T> forSettings<T>({
    required WidgetBuilder builder,
    String subpath = '',
  }) {
    final name = subpath.isEmpty
        ? ShellRouteNames.settings
        : '${ShellRouteNames.settings}/$subpath';
    return ShellMaterialPageRoute<T>(
      settings: RouteSettings(name: name),
      builder: builder,
    );
  }
}

/// Считает вложенные маршруты настроек и включает [ShellChromeVisibility.seeThroughOverlay].
class ShellSettingsRouteObserver extends NavigatorObserver {
  int _depth = 0;

  void _sync() {
    final next = _depth > 0;
    if (ShellChromeVisibility.seeThroughOverlay.value != next) {
      ShellChromeVisibility.seeThroughOverlay.value = next;
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (ShellRouteNames.isSettingsRoute(route.settings.name)) {
      _depth++;
      _sync();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (ShellRouteNames.isSettingsRoute(route.settings.name)) {
      _depth = (_depth - 1).clamp(0, 32);
      _sync();
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (ShellRouteNames.isSettingsRoute(route.settings.name)) {
      _depth = (_depth - 1).clamp(0, 32);
      _sync();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (ShellRouteNames.isSettingsRoute(oldRoute?.settings.name)) {
      _depth = (_depth - 1).clamp(0, 32);
    }
    if (ShellRouteNames.isSettingsRoute(newRoute?.settings.name)) {
      _depth++;
    }
    _sync();
  }
}
