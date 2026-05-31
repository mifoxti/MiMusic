import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/settings_glass_scaffold.dart';

/// Пресет эквалайзера: название и усиление полос в дБ (подписи на экране ориентировочные; центры полос задаёт Android).
class _EqualizerPreset {
  const _EqualizerPreset(this.name, this.gains);

  final String name;
  final List<double> gains;
}

/// Отдельный экран, целиком посвящённый эквалайзеру. Загружает/сохраняет через [SettingsRepository].
/// Применяет настройки к [AudioPlayerService] в реальном времени (Android).
class EqualizerPage extends StatefulWidget {
  const EqualizerPage({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
    required this.audioPlayerService,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AudioPlayerService audioPlayerService;

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  static const int _bands = 5;
  /// Узкий диапазон ±6 дБ: меньше клиппинга и резких провалов между полосами.
  static const double _eqMinDb = -6;
  static const double _eqMaxDb = 6;
  static const List<String> _labels = ['60', '230', '910', '3.6k', '14k'];

  List<_EqualizerPreset> _presets(BuildContext context) => [
    _EqualizerPreset(context.t('equalizer.preset.flat'), [0, 0, 0, 0, 0]),
    _EqualizerPreset(context.t('equalizer.preset.bass'), [3, 2, 0, -1, -1]),
    _EqualizerPreset(context.t('equalizer.preset.treble'), [-1, -1, 0, 1, 3]),
    _EqualizerPreset(context.t('equalizer.preset.vocal'), [-1, 1, 2, 1, -1]),
    _EqualizerPreset(context.t('equalizer.preset.rock'), [2, 2, 0, 1, 2]),
    _EqualizerPreset(context.t('equalizer.preset.jazz'), [2, 1, -1, 1, 2]),
    _EqualizerPreset(context.t('equalizer.preset.pop'), [1, 1, 0, -1, 1]),
    _EqualizerPreset(context.t('equalizer.preset.classic'), [2, 1, 1, 1, 2]),
  ];

  static const List<double> _dbTicks = [-6, -3, 0, 3, 6];

  late List<double> _gains;
  late double _preamp;
  int? _selectedPresetIndex;
  Timer? _eqApplyDebounce;
  Timer? _eqSaveDebounce;

  double _clampDb(double v) => v.clamp(_eqMinDb, _eqMaxDb);

  void _clampGainsInPlace() {
    for (var i = 0; i < _bands; i++) {
      _gains[i] = _clampDb(_gains[i]);
    }
    _preamp = _clampDb(_preamp);
  }

  @override
  void initState() {
    super.initState();
    final g = widget.initialSettings.equalizerGains;
    _gains = List.generate(_bands, (i) => i < g.length ? g[i] : 0.0);
    _preamp = widget.initialSettings.equalizerPreamp;
    _clampGainsInPlace();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_reloadEqualizerFromStorage());
    });
  }

  /// Актуальные значения с диска (после перезапуска и при повторном входе на экран).
  Future<void> _reloadEqualizerFromStorage() async {
    final s = await widget.settingsRepository.getSettings();
    if (!mounted) return;
    setState(() {
      final g = s.equalizerGains;
      _gains = List.generate(_bands, (i) => i < g.length ? g[i] : 0.0);
      _preamp = s.equalizerPreamp;
      _clampGainsInPlace();
    });
  }

  Future<void> _saveEqualizer() async {
    final current = await widget.settingsRepository.getSettings();
    await widget.settingsRepository.saveSettings(
      current.copyWith(equalizerGains: List.from(_gains), equalizerPreamp: _preamp),
    );
    await widget.audioPlayerService.applyEqualizerFromSettings();
  }

  void _scheduleApplyGainsDebounced() {
    _eqApplyDebounce?.cancel();
    _eqApplyDebounce = Timer(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      unawaited(widget.audioPlayerService.applyEqualizerGains(_gains));
    });
  }

  void _scheduleSaveDebounced() {
    _eqSaveDebounce?.cancel();
    _eqSaveDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      unawaited(_saveEqualizer());
    });
  }

  @override
  void dispose() {
    _eqApplyDebounce?.cancel();
    _eqSaveDebounce?.cancel();
    unawaited(_saveEqualizer());
    super.dispose();
  }

  Future<void> _applyPreset(int index) async {
    _eqApplyDebounce?.cancel();
    _eqSaveDebounce?.cancel();
    setState(() {
      _selectedPresetIndex = index;
      _gains = List<double>.from(_presets(context)[index].gains);
      _clampGainsInPlace();
    });
    await widget.audioPlayerService.applyEqualizerGains(_gains);
    await _saveEqualizer();
  }

  Future<void> _reset() async {
    _eqApplyDebounce?.cancel();
    _eqSaveDebounce?.cancel();
    setState(() {
      _gains = List.filled(_bands, 0.0);
      _preamp = 0.0;
      _selectedPresetIndex = 0;
    });
    await _saveEqualizer();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return SettingsGlassScaffold(
      title: context.t('settings.equalizer'),
      audioPlayerService: widget.audioPlayerService,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('settings.equalizerSub'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textSecondary),
            ),
            const SizedBox(height: 16),
            GlassPanel(child: _buildPresets(palette)),
            const SizedBox(height: 14),
            GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _buildDbScaleAndSliders(palette),
            ),
            const SizedBox(height: 14),
            GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _buildPreampContent(palette),
            ),
            const SizedBox(height: 20),
            _buildResetButton(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildPresets(AppColorPalette palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassSectionLabel(
          Localizations.localeOf(context).languageCode == 'en' ? 'Presets' : 'Пресеты',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(_presets(context).length, (i) {
                final preset = _presets(context)[i];
                return Padding(
                  padding: EdgeInsets.only(right: i < _presets(context).length - 1 ? 10 : 0),
                  child: GlassChoiceChip(
                    label: preset.name,
                    selected: _selectedPresetIndex == i,
                    compact: true,
                    onTap: () => _applyPreset(i),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreampContent(AppColorPalette palette) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Localizations.localeOf(context).languageCode == 'en' ? 'Bass boost' : 'Басс-буст',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              Text(
                '${_preamp.round()} ${Localizations.localeOf(context).languageCode == 'en' ? 'dB' : 'дБ'}',
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
              value: _preamp.clamp(_eqMinDb, _eqMaxDb),
              min: _eqMinDb,
              max: _eqMaxDb,
              divisions: 24,
              onChanged: (v) {
                setState(() => _preamp = v);
                _scheduleSaveDebounced();
              },
              onChangeEnd: (_) {
                _eqSaveDebounce?.cancel();
                unawaited(_saveEqualizer());
              },
            ),
          ),
        ],
    );
  }

  Widget _buildDbScaleAndSliders(AppColorPalette palette) {
    const sliderHeight = 156.0;
    const scaleRowHeight = 20.0;
    const gapScaleToSliders = 10.0;
    const labelsRowHeight = 44.0;
    const paddingV = 14.0;
    const columnSpacing = 6.0;
    const totalHeight = scaleRowHeight + gapScaleToSliders + sliderHeight + labelsRowHeight + paddingV * 2;

    return SizedBox(
      height: totalHeight,
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
                                      value: _gains[i].clamp(_eqMinDb, _eqMaxDb),
                                      min: _eqMinDb,
                                      max: _eqMaxDb,
                                      divisions: 24,
                                      onChanged: (v) {
                                        setState(() {
                                          _gains[i] = v;
                                          _selectedPresetIndex = null;
                                        });
                                        _scheduleApplyGainsDebounced();
                                      },
                                      onChangeEnd: (_) {
                                        _eqApplyDebounce?.cancel();
                                        unawaited(widget.audioPlayerService.applyEqualizerGains(_gains));
                                        unawaited(_saveEqualizer());
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
    );
  }

  Widget _buildResetButton(AppColorPalette palette) {
    return Center(
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: TextButton.icon(
          onPressed: () async => _reset(),
          icon: Icon(Icons.refresh_rounded, size: 18, color: palette.textSecondary),
          label: Text(
            Localizations.localeOf(context).languageCode == 'en' ? 'Reset' : 'Сбросить',
            style: TextStyle(
              fontSize: 14,
              color: palette.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
