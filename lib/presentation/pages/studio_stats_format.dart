import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_bottom_menu_sheet.dart';
import '../widgets/settings_glass_scaffold.dart';

/// Компактное число для статистики: 13890 → «13,9K» / «13,9к».
String formatStudioCompactCount(int n, BuildContext context) {
  if (n < 1000) return '$n';
  final isEn = Localizations.localeOf(context).languageCode == 'en';
  if (n >= 1000000) {
    final v = n / 1000000;
    final s = _oneDecimal(v, isEn);
    return isEn ? '${s}M' : '${s}млн';
  }
  final v = n / 1000;
  final s = _oneDecimal(v, isEn);
  return isEn ? '${s}K' : '${s}к';
}

String _oneDecimal(double v, bool isEn) {
  final rounded = (v * 10).round() / 10;
  final text = rounded.toStringAsFixed(1);
  return isEn ? text : text.replaceAll('.', ',');
}

/// Точное число с разделителем тысяч (13 890).
String formatStudioExactCount(int n, BuildContext context) {
  final isEn = Localizations.localeOf(context).languageCode == 'en';
  final negative = n < 0;
  final digits = n.abs().toString();
  final sep = isEn ? ',' : '\u00A0';
  final buf = StringBuffer();
  if (negative) buf.write('-');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(sep);
    buf.write(digits[i]);
  }
  return buf.toString();
}

bool studioCountIsCompact(int n) => n >= 1000;

Future<void> showStudioExactCountHint(
  BuildContext context, {
  required String title,
  required int count,
}) {
  return showGlassValueHint(
    context,
    title: title,
    value: formatStudioExactCount(count, context),
  );
}

EdgeInsets studioStatsListPadding(
  AudioPlayerService? audioPlayerService, {
  EdgeInsets base = const EdgeInsets.fromLTRB(16, 8, 16, 32),
}) {
  return base.copyWith(
    bottom: base.bottom +
        SettingsGlassScaffold.bottomContentInset(audioPlayerService),
  );
}

/// Счётчик прослушиваний в списке (компактно + точное по тапу).
class StudioPlayCountText extends StatelessWidget {
  const StudioPlayCountText({
    super.key,
    required this.count,
    required this.hintTitle,
    this.style,
  });

  final int count;
  final String hintTitle;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final textStyle = style ??
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.textSecondary,
        );
    final label = formatStudioCompactCount(count, context);
    if (!studioCountIsCompact(count)) {
      return Text(label, style: textStyle);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showStudioExactCountHint(
          context,
          title: hintTitle,
          count: count,
        ),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }
}
