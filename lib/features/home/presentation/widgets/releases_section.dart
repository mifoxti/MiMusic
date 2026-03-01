import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
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

  static const double _itemSize = 120.0;
  static const double _spacing = 14.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final paddingHorizontal = (screenWidth - _itemSize) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Последние релизы',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
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

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 120,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: palette.primaryDark.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(Icons.album, size: 48, color: palette.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: TextStyle(
                fontSize: 12,
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
