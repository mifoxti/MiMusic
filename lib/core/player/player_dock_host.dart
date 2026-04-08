/// Глобальная связка с [MainShell]: открыть/закрыть полный плеер без отдельного маршрута
/// (одна анимация расширения мини-плеера).
abstract final class PlayerDockHost {
  static void Function()? _expand;
  static void Function()? _collapse;

  static void register({
    required void Function() expand,
    required void Function() collapse,
  }) {
    _expand = expand;
    _collapse = collapse;
  }

  static void unregister() {
    _expand = null;
    _collapse = null;
  }

  /// Развернуть док (из мини-плеера или со страниц вроде «Чарты»).
  static void expand() => _expand?.call();

  /// Свернуть в мини-плеер.
  static void collapse() => _collapse?.call();
}
