import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Пресет эквалайзера: название и значения полос [60, 230, 910, 3600, 14000] Hz в дБ.
class _EqualizerPreset {
  const _EqualizerPreset(this.name, this.gains);

  final String name;
  final List<double> gains;
}

/// Отдельный экран, целиком посвящённый эквалайзеру. Загружает/сохраняет через [SettingsRepository].
class EqualizerPage extends StatefulWidget {
  const EqualizerPage({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  static const int _bands = 5;
  static const List<String> _labels = ['60', '230', '910', '3.6k', '14k'];

  static const List<_EqualizerPreset> _presets = [
    _EqualizerPreset('Плоский', [0, 0, 0, 0, 0]),
    _EqualizerPreset('Басы', [6, 4, 0, -2, -2]),
    _EqualizerPreset('Трели', [-2, -1, 0, 2, 6]),
    _EqualizerPreset('Вокал', [-1, 2, 4, 2, -1]),
    _EqualizerPreset('Рок', [5, 3, 0, 2, 4]),
    _EqualizerPreset('Джаз', [4, 2, -1, 1, 3]),
    _EqualizerPreset('Поп', [2, 1, 0, -1, 2]),
    _EqualizerPreset('Классика', [3, 1, 1, 2, 3]),
  ];

  static const List<double> _dbTicks = [-12, -6, 0, 6, 12];

  late List<double> _gains;
  late double _preamp;
  int? _selectedPresetIndex;

  @override
  void initState() {
    super.initState();
    final g = widget.initialSettings.equalizerGains;
    _gains = List.generate(_bands, (i) => i < g.length ? g[i] : 0.0);
    _preamp = widget.initialSettings.equalizerPreamp;
  }

  Future<void> _saveEqualizer() async {
    final current = await widget.settingsRepository.getSettings();
    await widget.settingsRepository.saveSettings(
      current.copyWith(equalizerGains: List.from(_gains), equalizerPreamp: _preamp),
    );
  }

  @override
  void dispose() {
    _saveEqualizer();
    super.dispose();
  }

  void _applyPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      _gains = List<double>.from(_presets[index].gains);
    });
  }

  void _reset() {
    setState(() {
      _gains = List.filled(_bands, 0.0);
      _preamp = 0.0;
      _selectedPresetIndex = 0;
    });
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
              _buildAppBar(palette),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Эквалайзер',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Пресеты и полосы частот',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: palette.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      _buildPresets(palette),
                      const SizedBox(height: 16),
                      _buildDbScaleAndSliders(palette),
                      const SizedBox(height: 16),
                      _buildPreamp(palette),
                      const SizedBox(height: 24),
                      _buildResetButton(palette),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(AppColorPalette palette) {
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
          const SizedBox(width: 48),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPresets(AppColorPalette palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ПРЕСЕТЫ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: palette.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
            children: List.generate(_presets.length, (i) {
              final preset = _presets[i];
              final isSelected = _selectedPresetIndex == i;
              return Padding(
                padding: EdgeInsets.only(right: i < _presets.length - 1 ? 10 : 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _applyPreset(i),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? palette.accent.withValues(alpha: 0.25)
                            : palette.cardBackground.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? palette.accent : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? palette.textPrimary : palette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreamp(AppColorPalette palette) {
    const boxHeight = 88.0;
    return SizedBox(
      height: boxHeight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: palette.cardBackground.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Предусиление',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                '${_preamp.round()} дБ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: palette.accent,
              inactiveTrackColor: palette.primaryDark.withValues(alpha: 0.35),
              thumbColor: palette.accent,
              overlayColor: palette.accent.withValues(alpha: 0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _preamp.clamp(-12.0, 12.0),
              min: -12,
              max: 12,
              divisions: 24,
              onChanged: (v) => setState(() => _preamp = v),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildDbScaleAndSliders(AppColorPalette palette) {
    const sliderHeight = 156.0;
    const scaleRowHeight = 20.0;
    const gapScaleToSliders = 10.0;
    const labelsRowHeight = 44.0;
    const paddingH = 16.0;
    const paddingV = 14.0;
    const columnSpacing = 6.0;
    const totalHeight = scaleRowHeight + gapScaleToSliders + sliderHeight + labelsRowHeight + paddingV * 2;

    return SizedBox(
      height: totalHeight,
      child: Container(
        padding: const EdgeInsets.only(left: paddingH, right: paddingH, top: paddingV, bottom: paddingV),
        decoration: BoxDecoration(
          color: palette.cardBackground.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Шкала дБ — сверху, над ползунками (каждая метка над своей колонкой)
            SizedBox(
              height: scaleRowHeight,
              child: Row(
                children: List.generate(_dbTicks.length, (i) {
                  final db = _dbTicks[i];
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: columnSpacing / 2),
                      child: Text(
                        db >= 0 ? '+$db' : '$db',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: palette.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: gapScaleToSliders),
            // Ползунки — под шкалой, колонки чуть ближе (columnSpacing)
            Expanded(
              child: Row(
                children: List.generate(_bands, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: columnSpacing / 2),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: sliderHeight,
                            child: Center(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: SizedBox(
                                  width: sliderHeight,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: palette.accent,
                                      inactiveTrackColor: palette.primaryDark.withValues(alpha: 0.35),
                                      thumbColor: palette.accent,
                                      overlayColor: palette.accent.withValues(alpha: 0.2),
                                      trackHeight: 8,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                                    ),
                                    child: Slider(
                                      value: _gains[i].clamp(-12.0, 12.0),
                                      min: -12,
                                      max: 12,
                                      divisions: 24,
                                      onChanged: (v) {
                                        setState(() {
                                          _gains[i] = v;
                                          _selectedPresetIndex = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '${_gains[i].round()}',
                            style: TextStyle(
                              fontSize: 10,
                              color: palette.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(AppColorPalette palette) {
    return TextButton.icon(
      onPressed: _reset,
      icon: Icon(Icons.refresh_rounded, size: 18, color: palette.textSecondary),
      label: Text(
        'Сбросить',
        style: TextStyle(fontSize: 14, color: palette.textSecondary, fontWeight: FontWeight.w500),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: palette.cardBackground.withValues(alpha: 0.6),
        foregroundColor: palette.textSecondary,
      ),
    );
  }
}
