import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Столбчатый график прослушиваний по дням (стеклянная палитра).
class GlassBarChart extends StatelessWidget {
  const GlassBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 160,
    this.barColor,
  });

  final List<int> values;
  final List<String> labels;
  final double height;
  final Color? barColor;

  static const double _dayLabelGap = 6;
  static const double _countGap = 2;
  static const double _minBarHeight = 4;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final accent = barColor ?? palette.accent;
    final maxVal = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 1 : maxVal;
    final showCounts = values.any((v) => v > 0);
    final countStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      color: palette.textMuted,
      height: 1.1,
    );
    final labelStyle = TextStyle(fontSize: 9, color: palette.textMuted, height: 1.1);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final v = values[i];
          final frac = v / maxY;
          final label = i < labels.length ? labels[i] : '';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showCounts) ...[
                    SizedBox(
                      height: (countStyle.fontSize ?? 9) * (countStyle.height ?? 1.0),
                      child: v > 0
                          ? Center(
                              child: Text('$v', style: countStyle),
                            )
                          : null,
                    ),
                    const SizedBox(height: _countGap),
                  ],
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final avail = constraints.maxHeight;
                        final barH = avail <= 0
                            ? 0.0
                            : (avail * frac).clamp(_minBarHeight, avail);
                        return Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            width: double.infinity,
                            height: v > 0 ? barH : 0,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  accent.withValues(alpha: 0.45),
                                  accent.withValues(alpha: 0.92),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: _dayLabelGap),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

String shortDayLabel(String isoDate) {
  if (isoDate.length < 10) return isoDate;
  final parts = isoDate.split('-');
  if (parts.length < 3) return isoDate;
  return '${parts[2]}.${parts[1]}';
}
