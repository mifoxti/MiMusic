import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'glass_panel.dart';

/// Общая оболочка профиля: коллапсирующая обложка + аватар с плавным смещением.
class CollapsingProfileShell extends StatelessWidget {
  const CollapsingProfileShell({
    super.key,
    required this.title,
    required this.cover,
    required this.avatar,
    required this.body,
    this.headerActions,
    this.trailingActions,
    this.audioPlayerService,
    this.onRefresh,
    this.leading,
  });

  static const double coverAspectRatio = 1.25;
  static const double avatarMaxSize = 84;
  static const double avatarMinSize = 40;

  final String title;
  final Widget cover;
  final Widget avatar;
  final Widget body;
  final Widget? headerActions;
  final Widget? trailingActions;
  final AudioPlayerService? audioPlayerService;
  final Future<void> Function()? onRefresh;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final coverHeight =
        (size.width * coverAspectRatio).clamp(260.0, size.height * 0.58);
    final expandedHeight = coverHeight + 96;
    final collapsedHeight = kToolbarHeight + topPadding + 12;

    final hasMini = audioPlayerService?.currentTrack != null;
    final bottomInset = hasMini
        ? AppConstants.shellBottomInsetWithMiniPlayer
        : AppConstants.shellBottomInset;

    Widget scroll = CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: onRefresh!),
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          expandedHeight: expandedHeight,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          forceMaterialTransparency: true,
          flexibleSpace: LayoutBuilder(
            builder: (context, constraints) {
              final currentHeight = constraints.maxHeight;
              final t = ((currentHeight - collapsedHeight) /
                      (expandedHeight - collapsedHeight))
                  .clamp(0.0, 1.0);
              final easedT = Curves.easeInOut.transform(t);
              final avatarSize =
                  lerpDouble(avatarMinSize, avatarMaxSize, t)!;
              final titleSize = lerpDouble(18, 28, t)!;
              // Как на скрине: блок (аватар + ник + «Мысли») по центру обложки,
              // при скролле уезжает влево-вверх.
              final alignment = Alignment.lerp(
                const Alignment(-0.9, -0.2),
                const Alignment(0, 0.7),
                t,
              )!;
              final nicknameOffsetY = lerpDouble(0, -10, easedT)!;
              final buttonVisibility = easedT;

              final top = MediaQuery.paddingOf(context).top;

              return Stack(
                fit: StackFit.expand,
                children: [
                  SizedBox(
                    width: size.width,
                    height: coverHeight,
                    child: cover,
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            palette.gradientEnd.withValues(alpha: 0.98),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: alignment,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: lerpDouble(16, 24, t)!,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: avatarSize,
                            height: avatarSize,
                            child: avatar,
                          ),
                          const SizedBox(width: 14),
                          Transform.translate(
                            offset: Offset(0, nicknameOffsetY),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                if (headerActions != null) ...[
                                  SizedBox(height: 8 * buttonVisibility),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    heightFactor: buttonVisibility == 0
                                        ? 0.001
                                        : buttonVisibility,
                                    child: Opacity(
                                      opacity: buttonVisibility,
                                      child: headerActions,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (leading != null || Navigator.of(context).canPop())
                    Positioned(
                      top: top + 8,
                      left: 8,
                      child: leading ??
                          GlassIconButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                    ),
                  if (trailingActions != null)
                    Positioned(
                      top: top + 8,
                      right: 8,
                      child: trailingActions!,
                    ),
                ],
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.gradientMiddle,
                  palette.gradientEnd,
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusXLarge),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset),
              child: body,
            ),
          ),
        ),
      ],
    );

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
      child: scroll,
    );
  }
}

/// Секция профиля со стеклянной панелью.
class ProfileGlassSection extends StatelessWidget {
  const ProfileGlassSection({
    super.key,
    required this.title,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          GlassPanel(padding: EdgeInsets.zero, child: child),
        ],
      ),
    );
  }
}
