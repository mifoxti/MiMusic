import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Совместное прослушивание — основная фича приложения (пока заглушка до бэкенда комнат).
class ListeningRoomPage extends StatelessWidget {
  const ListeningRoomPage({super.key});

  static const String routeName = 'mimusic_listening_room';

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.gradientStart,
            palette.gradientMiddle,
            palette.gradientEnd,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Совместное прослушивание'),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: palette.textPrimary),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.groups_rounded,
                  size: 72,
                  color: palette.accent.withValues(alpha: 0.9),
                ),
                const SizedBox(height: 24),
                Text(
                  'Создайте комнату и слушайте музыку вместе с друзьями в реальном времени.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Комнаты появятся в следующем обновлении',
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: palette.cardBackground,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Создать комнату'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
