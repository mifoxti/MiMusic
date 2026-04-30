import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

class ReleasePage extends StatelessWidget {
  const ReleasePage({
    super.key,
    required this.title,
    this.coverUrl,
  });

  final String title;
  final String? coverUrl;

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
          backgroundColor: Colors.transparent,
          title: const Text('Релиз'),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: (coverUrl ?? '').isNotEmpty
                      ? Image.network(
                          coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(palette),
                        )
                      : _placeholder(palette),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Экран открыт из уведомления',
                style: TextStyle(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(AppColorPalette palette) {
    return Container(
      color: palette.primaryLight.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Icon(
        Icons.album_rounded,
        size: 60,
        color: palette.textMuted,
      ),
    );
  }
}
