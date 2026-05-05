import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../fragments/personal_settings_fragment.dart';

/// Отдельный экран персональных настроек: только профиль. Тема в общих настройках.
class PersonalSettingsPage extends StatefulWidget {
  const PersonalSettingsPage({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
    required this.audioPlayerService,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AudioPlayerService audioPlayerService;

  @override
  State<PersonalSettingsPage> createState() => _PersonalSettingsPageState();
}

class _PersonalSettingsPageState extends State<PersonalSettingsPage> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadFromRepository());
  }

  Future<void> _reloadFromRepository() async {
    final s = await widget.settingsRepository.getSettings();
    if (!mounted) return;
    setState(() => _settings = s);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return Scaffold(
      body: Container(
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
              _buildAppBar(context, palette),
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.audioPlayerService,
                  builder: (context, _) {
                    final hasMini = widget.audioPlayerService.currentTrack != null;
                    // Те же отступы, что у [SettingsPage]: только нижняя навигация или навигация + мини-плеер.
                    final bottomPad = hasMini
                        ? AppConstants.shellBottomInsetWithMiniPlayer
                        : AppConstants.shellBottomInset;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildContentCard(
                            palette,
                            child: PersonalSettingsFragment(
                              settingsRepository: widget.settingsRepository,
                              initialSettings: _settings,
                              onProfileSaved: _reloadFromRepository,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, AppColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: palette.textPrimary),
            style: IconButton.styleFrom(
              backgroundColor: palette.cardBackground.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          Text(
            context.t('settings.personal'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildContentCard(AppColorPalette palette, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
