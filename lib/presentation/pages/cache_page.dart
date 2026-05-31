import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/cache/cache_size.dart';
import '../../core/offline/offline_download_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_glass.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/settings_glass_scaffold.dart';

/// Дискретные позиции слайдера лимита.
/// «0» — нулевой лимит (0 байт). «∞» — [AppSettings.cacheLimitUnlimited] (-1).
const List<int> _cacheLimitSteps = [
  0,
  100 * 1024 * 1024,
  200 * 1024 * 1024,
  500 * 1024 * 1024,
  1 * 1024 * 1024 * 1024,
  5 * 1024 * 1024 * 1024,
  AppSettings.cacheLimitUnlimited,
];

/// Кэш: кольцо занятого места, лимит, очистка.
class CachePage extends StatefulWidget {
  const CachePage({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
    this.audioPlayerService,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AudioPlayerService? audioPlayerService;

  @override
  State<CachePage> createState() => _CachePageState();
}

class _CachePageState extends State<CachePage> with TickerProviderStateMixin {
  int? _usedBytes;
  bool _loading = true;
  late int _limitBytes;

  /// Отображаемое занятое место (анимируется к нулю после очистки).
  late int _displayUsedBytes;

  late final AnimationController _clearAnimController;
  Animation<double>? _clearUsedAnimation;

  @override
  void initState() {
    super.initState();
    _limitBytes = widget.initialSettings.cacheLimitBytes;
    _displayUsedBytes = 0;
    _clearAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLimitFromRepository();
    });
    _refreshSize();
  }

  /// Актуальный лимит из [SettingsRepository] (SharedPreferences), не устаревший снимок с старта приложения.
  Future<void> _loadLimitFromRepository() async {
    final s = await widget.settingsRepository.getSettings();
    if (!mounted) return;
    setState(() => _limitBytes = s.cacheLimitBytes);
  }

  @override
  void dispose() {
    _clearAnimController.dispose();
    super.dispose();
  }

  /// Индекс шага для текущего лимита (в т.ч. ближайший к сохранённому значению).
  int _stepIndexForLimit(int bytes) {
    if (bytes == AppSettings.cacheLimitUnlimited) {
      return _cacheLimitSteps.length - 1;
    }
    final exact = _cacheLimitSteps.indexWhere((s) => s == bytes);
    if (exact >= 0) return exact;
    var bestI = 0;
    var bestDelta = 1 << 62;
    for (var i = 0; i < _cacheLimitSteps.length; i++) {
      final b = _cacheLimitSteps[i];
      if (b < 0) continue;
      final d = (bytes - b).abs();
      if (d < bestDelta) {
        bestDelta = d;
        bestI = i;
      }
    }
    return bestI;
  }

  Future<void> _refreshSize() async {
    setState(() => _loading = true);
    final n = await getAppCacheSizeBytes();
    final offlineRepo = OfflineDownloadRepository(
      settingsRepository: widget.settingsRepository,
    );
    await offlineRepo.ensureLoaded();
    final offline = await offlineRepo.getOfflineDownloadsSizeBytes();
    if (!mounted) return;
    setState(() {
      _usedBytes = n + offline;
      _displayUsedBytes = n + offline;
      _loading = false;
    });
  }

  Future<void> _saveLimit(int bytes) async {
    final current = await widget.settingsRepository.getSettings();
    await widget.settingsRepository.saveSettings(
      current.copyWith(cacheLimitBytes: bytes),
    );
    if (!mounted) return;
    setState(() {
      _limitBytes = bytes;
    });
  }

  Future<void> _confirmAndClear() async {
    final ok = await _showGlassConfirmDialog();
    if (ok != true || !mounted) return;

    final before = _displayUsedBytes;
    await clearAppCache();
    final after = await getAppCacheSizeBytes();
    if (!mounted) return;

    setState(() {
      _usedBytes = after;
      _loading = false;
    });

    _clearUsedAnimation?.removeListener(_onClearAnimTick);
    _clearAnimController.reset();
    _clearUsedAnimation = Tween<double>(
      begin: before.toDouble(),
      end: after.toDouble(),
    ).animate(
      CurvedAnimation(
        parent: _clearAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _clearUsedAnimation!.addListener(_onClearAnimTick);
    _clearAnimController.forward(from: 0).whenComplete(() {
      _clearUsedAnimation?.removeListener(_onClearAnimTick);
      if (!mounted) return;
      setState(() {
        _displayUsedBytes = _usedBytes ?? 0;
      });
    });

    if (!mounted) return;
    final palette = AppPaletteExtension.of(context).palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('cache.cleared')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.cardBackground,
      ),
    );
  }

  void _onClearAnimTick() {
    final anim = _clearUsedAnimation;
    if (anim == null || !mounted) return;
    setState(() {
      _displayUsedBytes = anim.value.round().clamp(0, 1 << 30);
    });
  }

  /// Диалог подтверждения в стиле стекла мини-плеера.
  Future<bool?> _showGlassConfirmDialog() {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final p = AppPaletteExtension.of(ctx).palette;
        final glassTint = AppGlass.tint(isDark);
        final borderGlass = AppGlass.border(isDark);
        const radius = AppConstants.radiusLarge;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: AppGlass.blurredTintLayer(
                isDark: isDark,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: borderGlass, width: 1),
                    color: glassTint,
                    boxShadow: AppGlass.cardShadows(isDark),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.t('cache.confirmTitle'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.t('cache.confirmText'),
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                context.t('common.cancel'),
                                style: TextStyle(color: p.textSecondary),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                context.t('cache.clear'),
                                style: TextStyle(
                                  color: p.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final used = _displayUsedBytes;
    final unlimited = _limitBytes == AppSettings.cacheLimitUnlimited;
    final hasCap = !unlimited;
    final limitForRing = _limitBytes <= 0 && hasCap ? 1 : _limitBytes;
    final ratio = unlimited
        ? 0.0
        : hasCap && _limitBytes == 0
            ? (used > 0 ? 1.0 : 0.0)
            : (used / limitForRing).clamp(0.0, 1.0);
    final overLimit = unlimited
        ? false
        : _limitBytes == 0
            ? (_usedBytes ?? 0) > 0
            : (_usedBytes ?? 0) > _limitBytes;
    final limitStepIndex = _stepIndexForLimit(_limitBytes);

    const ringSize = 220.0;

    return SettingsGlassScaffold(
      title: context.t('cache.title'),
      audioPlayerService: widget.audioPlayerService,
      child: SettingsGlassScrollView(
        audioPlayerService: widget.audioPlayerService,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: SizedBox(
                          width: ringSize,
                          height: ringSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(ringSize, ringSize),
                                painter: _CacheRingPainter(
                                  progress: ratio,
                                  trackColor: palette.primaryLight.withValues(alpha: 0.85),
                                  progressColor: overLimit
                                      ? palette.textSecondary
                                      : palette.accent,
                                  strokeWidth: 16,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_loading)
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: palette.accent,
                                      ),
                                    )
                                  else ...[
                                    Text(
                                      _formatBytes(used),
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: palette.textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      unlimited
                                          ? context.t('cache.unlimited')
                                          : _limitBytes == 0
                                              ? 'из 0'
                                              : context.tr('cache.of', {'size': _formatBytes(_limitBytes)}),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                    if (overLimit) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        context.t('cache.overLimit'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      GlassSectionLabel(context.t('cache.allowed')),
                      const SizedBox(height: 12),
                      GlassPanel(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: palette.accent,
                                inactiveTrackColor: palette.primaryLight
                                    .withValues(alpha: 0.75),
                                thumbColor: palette.accent,
                                overlayColor: palette.accent.withValues(alpha: 0.2),
                                trackHeight: 5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 18,
                                ),
                              ),
                              child: Slider(
                                value: limitStepIndex.toDouble(),
                                min: 0,
                                max: (_cacheLimitSteps.length - 1).toDouble(),
                                divisions: _cacheLimitSteps.length - 1,
                                onChanged: (v) {
                                  final idx =
                                      v.round().clamp(0, _cacheLimitSteps.length - 1);
                                  _saveLimit(_cacheLimitSteps[idx]);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(_cacheLimitSteps.length, (i) {
                                  final selected = i == limitStepIndex;
                                  return Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Center(
                                          child: Container(
                                            width: 2,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: palette.textMuted.withValues(
                                                alpha: selected ? 0.95 : 0.55,
                                              ),
                                              borderRadius: BorderRadius.circular(1),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _cacheStepLabel(_cacheLimitSteps[i]),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.fade,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            height: 1.15,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            color: selected
                                                ? palette.textPrimary
                                                : palette.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: _loading ? null : _confirmAndClear,
                        icon: const Icon(Icons.delete_sweep_rounded, size: 22),
                        label: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            context.t('cache.clear'),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.t('cache.note'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes ${context.t('cache.bytes')}';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} ${context.t('cache.kb')}';
    final mb = bytes / (1024 * 1024);
    if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} ${context.t('cache.mb')}';
    final gb = bytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(gb >= 10 ? 1 : 2)} ${context.t('cache.gb')}';
  }

  String _cacheStepLabel(int bytes) {
    if (bytes == AppSettings.cacheLimitUnlimited) return '∞';
    if (bytes == 0) return '0';
    return _formatBytes(bytes);
  }
}

/// Замкнутое кольцо 360°: фон + дуга прогресса (только обводка).
class _CacheRingPainter extends CustomPainter {
  _CacheRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  /// Сверху (−90°), полный оборот по часовой стрелке.
  static const double _startRad = -math.pi / 2;
  static const double _fullSweep = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _startRad, _fullSweep, false, trackPaint);

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    canvas.drawArc(rect, _startRad, _fullSweep * p, false, progPaint);
  }

  @override
  bool shouldRepaint(covariant _CacheRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
