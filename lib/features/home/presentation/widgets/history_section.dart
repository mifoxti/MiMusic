import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/history/listening_history_entry.dart';
import '../../../../core/history/listening_history_repository.dart';
import '../../../../core/l10n/app_localization.dart';
import '../../../../core/network/tracks_api.dart';
import '../../../../core/theme/app_glass.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/track_cover.dart';

class _HistoryCoverPack {
  const _HistoryCoverPack({required this.trackId, required this.source});

  final int trackId;
  final dynamic source;
}

/// Карточка «История» с подгрузкой обложек для мозаики 2×2.
class HistorySectionCard extends StatefulWidget {
  const HistorySectionCard({
    super.key,
    required this.subtitle,
    required this.listeningHistoryRepository,
    this.onTap,
    this.title,
  });

  final String? title;
  final String subtitle;
  final VoidCallback? onTap;
  final ListeningHistoryRepository listeningHistoryRepository;

  @override
  State<HistorySectionCard> createState() => _HistorySectionCardState();
}

class _HistorySectionCardState extends State<HistorySectionCard> {
  List<dynamic> _coverSources = const ['', '', '', ''];
  int _loadGen = 0;

  @override
  void initState() {
    super.initState();
    widget.listeningHistoryRepository.addListener(_onHistoryChanged);
    unawaited(_reloadCovers());
  }

  @override
  void didUpdateWidget(covariant HistorySectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listeningHistoryRepository != widget.listeningHistoryRepository) {
      oldWidget.listeningHistoryRepository.removeListener(_onHistoryChanged);
      widget.listeningHistoryRepository.addListener(_onHistoryChanged);
      unawaited(_reloadCovers());
    }
  }

  @override
  void dispose() {
    widget.listeningHistoryRepository.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    unawaited(_reloadCovers());
  }

  Future<_HistoryCoverPack?> _coverFor(ListeningHistoryEntry e) async {
    final id = TracksApi().parseServerTrackId(e.playablePath);
    if (id == null) return null;
    try {
      final t = await TracksApi().fetchTrackById(id);
      if (t.coverBytes != null && t.coverBytes!.isNotEmpty) {
        return _HistoryCoverPack(trackId: id, source: t.coverBytes);
      }
      return _HistoryCoverPack(trackId: id, source: t.coverUrl());
    } catch (_) {
      final c = e.coverAssetPath?.trim();
      if (c != null && c.isNotEmpty) {
        return _HistoryCoverPack(trackId: id, source: c);
      }
    }
    return null;
  }

  Future<void> _reloadCovers() async {
    final gen = ++_loadGen;
    final entries = widget.listeningHistoryRepository.entries;
    final slots = List<dynamic>.filled(4, '');
    final usedTrackIds = <int>{};

    bool applySlot(int index, _HistoryCoverPack? pack) {
      if (pack == null || usedTrackIds.contains(pack.trackId)) return false;
      if (!_isUsableCover(pack.source)) return false;
      usedTrackIds.add(pack.trackId);
      slots[index] = pack.source;
      return true;
    }

    for (var i = 0; i < 4 && i < entries.length; i++) {
      applySlot(i, await _coverFor(entries[i]));
    }

    for (var slot = 0; slot < 4; slot++) {
      if (_isUsableCover(slots[slot])) continue;
      for (var j = 4; j < entries.length && j < 16; j++) {
        final id = TracksApi().parseServerTrackId(entries[j].playablePath);
        if (id != null && usedTrackIds.contains(id)) continue;
        if (applySlot(slot, await _coverFor(entries[j]))) break;
      }
    }

    if (gen != _loadGen || !mounted) return;
    setState(() => _coverSources = slots);
  }

  static bool _isUsableCover(dynamic source) {
    if (source == null) return false;
    if (source is Uint8List || source is List<int>) {
      return source.isNotEmpty;
    }
    if (source is String) return source.trim().isNotEmpty;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return HistorySection(
      title: widget.title,
      subtitle: widget.subtitle,
      onTap: widget.onTap,
      coverSources: _coverSources,
    );
  }
}

/// Карточка «История»: слева квадрат 2×2 на всю высоту карточки, вплотную к краю.
class HistorySection extends StatelessWidget {
  const HistorySection({
    super.key,
    required this.subtitle,
    this.onTap,
    this.title,
    this.coverSources = const [],
  });

  final String? title;
  final String subtitle;
  final VoidCallback? onTap;
  final List<dynamic> coverSources;

  static double _cardHeight({required bool hasSubtitle}) =>
      hasSubtitle ? 88 : 64;

  static const _innerCoverRadius = 10.0;

  static BorderRadius _coverGridClipRadius() {
    const r = AppConstants.radiusLarge;
    return BorderRadius.only(
      topLeft: Radius.circular(r),
      bottomLeft: Radius.circular(r),
      topRight: Radius.circular(_innerCoverRadius),
      bottomRight: Radius.circular(_innerCoverRadius),
    );
  }

  static BorderRadius _coverCellRadius(int index) {
    const r = AppConstants.radiusLarge;
    const inner = _innerCoverRadius;
    return switch (index) {
      0 => BorderRadius.only(topLeft: Radius.circular(r)),
      1 => BorderRadius.only(topRight: Radius.circular(inner)),
      2 => BorderRadius.only(bottomLeft: Radius.circular(r)),
      3 => BorderRadius.only(bottomRight: Radius.circular(inner)),
      _ => BorderRadius.zero,
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSubtitle = subtitle.trim().isNotEmpty;
    final cardHeight = _cardHeight(hasSubtitle: hasSubtitle);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: AppGlass.blurredTintLayer(
            isDark: isDark,
            child: Container(
              height: cardHeight,
              decoration: BoxDecoration(
                color: AppGlass.tint(isDark),
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                border: Border.all(color: AppGlass.border(isDark)),
                boxShadow: AppGlass.cardShadows(isDark),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: _coverGridClipRadius(),
                    child: SizedBox(
                      width: cardHeight,
                      child: _buildCoverGrid(palette, isDark),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title ?? context.t('history.title'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                color: palette.textPrimary,
                              ),
                            ),
                            if (hasSubtitle) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: palette.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverGrid(AppColorPalette palette, bool isDark) {
    final cells = coverSources.take(4).toList();
    while (cells.length < 4) {
      cells.add('');
    }

    return GridView.count(
      crossAxisCount: 2,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 0,
      crossAxisSpacing: 0,
      children: [
        for (var i = 0; i < 4; i++) _coverCell(cells[i], palette, isDark, i),
      ],
    );
  }

  Widget _coverCell(
    dynamic source,
    AppColorPalette palette,
    bool isDark,
    int index,
  ) {
    final radius = _coverCellRadius(index);
    final emptyColor = Color.lerp(
      palette.primaryDark,
      isDark ? Colors.black : Colors.white,
      isDark ? 0.35 : 0.12,
    )!;

    final placeholder = ColoredBox(color: emptyColor);

    Widget inner;
    if (source == null || (source is String && source.trim().isEmpty)) {
      inner = placeholder;
    } else if (source is Uint8List || source is List<int>) {
      inner = buildTrackCover(
        coverSource: source,
        width: double.infinity,
        height: double.infinity,
        borderRadius: radius,
        placeholder: placeholder,
        fit: BoxFit.cover,
      );
    } else {
      inner = buildCoverImage(
        imageUrl: source as String,
        width: double.infinity,
        height: double.infinity,
        borderRadius: radius,
        placeholder: placeholder,
        fit: BoxFit.cover,
      );
    }

    return ClipRRect(borderRadius: radius, child: inner);
  }
}
