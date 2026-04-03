import 'package:flutter/foundation.dart';

/// Глобальный флаг: полноэкранный плеер открыт — мини-плеер в shell скрывается.
class FullPlayerVisibility {
  FullPlayerVisibility._();

  static final ValueNotifier<bool> open = ValueNotifier<bool>(false);
}
