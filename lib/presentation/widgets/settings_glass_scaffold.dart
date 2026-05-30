import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'glass_panel.dart';

/// Общий каркас экранов настроек: градиент, стеклянная шапка, отступ под мини-плеер.
class SettingsGlassScaffold extends StatelessWidget {
  const SettingsGlassScaffold({
    super.key,
    required this.title,
    required this.child,
    this.audioPlayerService,
    this.showTitleInAppBar = true,
  });

  final String title;
  final Widget child;
  final AudioPlayerService? audioPlayerService;
  final bool showTitleInAppBar;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    Widget scaffoldBody(double bottomPad) {
      return Container(
        width: double.infinity,
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
        child: SafeArea(
          child: Column(
            children: [
              SettingsGlassAppBar(
                title: showTitleInAppBar ? title : null,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomPad),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (audioPlayerService == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: scaffoldBody(AppConstants.shellBottomInset),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: audioPlayerService!,
        builder: (context, _) {
          final hasMini = audioPlayerService!.currentTrack != null;
          final bottomPad = hasMini
              ? AppConstants.shellBottomInsetWithMiniPlayer
              : AppConstants.shellBottomInset;
          return scaffoldBody(bottomPad);
        },
      ),
    );
  }
}

/// Стеклянная кнопка «назад» и заголовок для экранов настроек.
class SettingsGlassAppBar extends StatelessWidget {
  const SettingsGlassAppBar({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconColor: palette.textPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          if (title != null)
            Text(
              title!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
