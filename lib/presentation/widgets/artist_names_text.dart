import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/player/shell_navigator_host.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../pages/artist_page.dart';

/// Список имён исполнителей из строки API (через запятую). Каждое имя — отдельная ссылка.
List<String> parseArtistDisplayNames(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[,;]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Одна или несколько кликабельных ссылок на страницу автора.
class ArtistNamesText extends StatelessWidget {
  const ArtistNamesText({
    super.key,
    required this.artistsText,
    this.style,
    this.textAlign,
    this.separator = ', ',
    this.audioPlayerService,
    this.onBeforeNavigate,
  });

  final String artistsText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final String separator;
  final AudioPlayerService? audioPlayerService;
  final VoidCallback? onBeforeNavigate;

  void _openArtist(BuildContext context, String name) {
    onBeforeNavigate?.call();
    final route = ShellMaterialPageRoute<void>(
      builder: (_) => ArtistPage(
        artistName: name,
        audioPlayerService: audioPlayerService,
      ),
    );
    final pushed = ShellNavigatorHost.push(route);
    if (!pushed) {
      Navigator.of(context).push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = parseArtistDisplayNames(artistsText);
    if (names.isEmpty) {
      return Text(
        artistsText,
        style: style,
        textAlign: textAlign,
      );
    }
    if (names.length == 1) {
      return InkWell(
        onTap: () => _openArtist(context, names.first),
        borderRadius: BorderRadius.circular(6),
        child: Text(
          names.first,
          style: style,
          textAlign: textAlign,
        ),
      );
    }
    final align = textAlign ?? TextAlign.start;
    return Wrap(
      alignment: align == TextAlign.center
          ? WrapAlignment.center
          : align == TextAlign.end
              ? WrapAlignment.end
              : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < names.length; i++) ...[
          if (i > 0)
            Text(separator, style: style?.copyWith(decoration: TextDecoration.none)),
          InkWell(
            onTap: () => _openArtist(context, names[i]),
            borderRadius: BorderRadius.circular(6),
            child: Text(names[i], style: style),
          ),
        ],
      ],
    );
  }
}
