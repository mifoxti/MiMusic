import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../domain/entities/release_item.dart';

/// Горизонтальный карусельный список «Последние релизы» по центру с прокруткой слева направо.
class ReleasesSection extends StatelessWidget {
  const ReleasesSection({
    super.key,
    required this.releases,
    this.onItemTap,
  });

  final List<ReleaseItem> releases;
  final void Function(ReleaseItem item)? onItemTap;

  static const double _itemSize = 152.0;
  static const double _spacing = 16.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final paddingHorizontal = (screenWidth - _itemSize) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('home.latestReleases'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
            itemCount: releases.length,
            itemBuilder: (context, index) {
              final item = releases[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < releases.length - 1 ? _spacing : 0,
                ),
                child: _ReleaseChip(
                  item: item,
                  onTap: () => onItemTap?.call(item),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReleaseChip extends StatelessWidget {
  const _ReleaseChip({required this.item, this.onTap});

  final ReleaseItem item;
  final VoidCallback? onTap;

  static const double _coverSize = 152.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _coverSize,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildCoverImage(
              imageUrl: item.coverUrl,
              width: _coverSize,
              height: _coverSize,
              borderRadius: BorderRadius.circular(_coverSize / 2),
              placeholder: Container(
                color: palette.primaryDark.withValues(alpha: 0.6),
                alignment: Alignment.center,
                child: Icon(Icons.album, size: 64, color: palette.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: palette.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
