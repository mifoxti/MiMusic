import 'package:flutter/material.dart';

/// Доступ к выходу из аккаунта из глубины дерева (например, [SettingsPage]).
class SessionScope extends InheritedWidget {
  const SessionScope({
    super.key,
    required this.onSignOut,
    required super.child,
  });

  final Future<void> Function() onSignOut;

  static SessionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>();
  }

  static SessionScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'SessionScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(SessionScope oldWidget) =>
      onSignOut != oldWidget.onSignOut;
}
