import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_glass.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cover_image.dart';
import '../../core/widgets/marquee_text.dart';
import '../../features/home/domain/entities/listening_friend.dart';

/// Стеклянная карточка комнаты совместного прослушивания (как на главной).
class ColistenListeningCard extends StatefulWidget {
  const ColistenListeningCard({
    super.key,
    required this.title,
    required this.artistName,
    required this.listeners,
    this.coverUrl,
    this.positionSeconds = 0,
    this.durationSeconds,
    this.playing = false,
    this.wallClockMs = 0,
    this.listenerCount,
    this.onTap,
  });

  final String title;
  final String artistName;
  final String? coverUrl;
  final List<ListeningFriend> listeners;
  final double positionSeconds;
  final int? durationSeconds;
  final bool playing;
  final int wallClockMs;
  final int? listenerCount;
  final VoidCallback? onTap;

  @override
  State<ColistenListeningCard> createState() => _ColistenListeningCardState();
}

class _ColistenListeningCardState extends State<ColistenListeningCard> {
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant ColistenListeningCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playing != widget.playing ||
        oldWidget.durationSeconds != widget.durationSeconds ||
        oldWidget.wallClockMs != widget.wallClockMs) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _progressTimer?.cancel();
    if (!widget.playing) return;
    if (widget.durationSeconds == null || widget.durationSeconds! <= 0) return;
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  double get _trackProgress {
    final duration = widget.durationSeconds;
    if (duration == null || duration <= 0) return 0;
    var position = widget.positionSeconds;
    if (widget.playing && widget.wallClockMs > 0) {
      final elapsedMs =
          DateTime.now().millisecondsSinceEpoch - widget.wallClockMs;
      if (elapsedMs > 0) position += elapsedMs / 1000.0;
    }
    return (position / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasTrack = widget.title.trim().isNotEmpty;
    final count = widget.listenerCount ?? widget.listeners.length;
    final listeningLabel = count > 0
        ? '${context.t('home.listeningNow')} · $count'
        : context.t('home.listeningNow');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: AppGlass.blurredTintLayer(
            isDark: isDark,
            child: Stack(
              children: [
                if (hasTrack)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final progress = _trackProgress;
                        return Row(
                          children: [
                            SizedBox(
                              width: constraints.maxWidth * progress,
                              child: Container(
                                color: palette.accent.withValues(alpha: 0.35),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                color: AppGlass.tint(isDark).withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                SizedBox(
                  height: 110,
                  child: Container(
                    padding: const EdgeInsets.only(left: 12, top: 10, bottom: 10),
                    decoration: BoxDecoration(
                      color: AppGlass.tint(isDark),
                      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                      border: Border.all(color: AppGlass.border(isDark)),
                      boxShadow: AppGlass.cardShadows(isDark),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasTrack) ...[
                          _CoverThumb(
                            coverUrl: widget.coverUrl,
                            palette: palette,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _TrackTitleMarquee(
                              title: widget.title,
                              artistName: widget.artistName,
                              palette: palette,
                            ),
                          ),
                        ),
                        if (widget.listeners.isNotEmpty)
                          Flexible(
                            fit: FlexFit.loose,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listeningLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _ListeningList(
                                      friends: widget.listeners.take(4).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.coverUrl, required this.palette});

  final String? coverUrl;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    const radius = AppConstants.radiusLarge;
    const side = 90.0;
    return SizedBox(
      width: side,
      height: side,
      child: buildCoverImage(
        imageUrl: coverUrl,
        width: side,
        height: side,
        borderRadius: BorderRadius.circular(radius),
        placeholder: Container(
          color: palette.accent.withValues(alpha: 0.6),
          alignment: Alignment.center,
          child: const Icon(Icons.music_note, color: Colors.white54, size: 40),
        ),
      ),
    );
  }
}

class _TrackTitleMarquee extends StatelessWidget {
  const _TrackTitleMarquee({
    required this.title,
    required this.artistName,
    required this.palette,
  });

  final String title;
  final String artistName;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarqueeText(
          text: title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        if (artistName.isNotEmpty) ...[
          const SizedBox(height: 4),
          MarqueeText(
            text: artistName,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ],
      ],
    );
  }
}

const _avatarShadow = [
  BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
];

class _ListeningList extends StatelessWidget {
  const _ListeningList({required this.friends});

  final List<ListeningFriend> friends;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    const radius = 12.0;
    const overlap = 6.0;
    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }
    final step = radius * 2 - overlap;
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AvatarStack(friends: friends),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < friends.length; i++)
                  SizedBox(
                    height: i < friends.length - 1 ? step : radius * 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        friends[i].username,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.friends});

  final List<ListeningFriend> friends;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    const radius = 12.0;
    const overlap = 6.0;
    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }
    final step = radius * 2 - overlap;
    final totalHeight = radius * 2 + (friends.length - 1) * step;
    return SizedBox(
      width: radius * 2,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < friends.length; i++)
            Positioned(
              left: 0,
              top: i * step,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _avatarShadow,
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: radius * 2,
                    height: radius * 2,
                    child: _AvatarImage(friend: friends[i], palette: palette),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.friend, required this.palette});

  final ListeningFriend friend;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: palette.accent.withValues(alpha: 0.5),
      child: Center(
        child: Text(
          friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 12,
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    final avatarUrl = friend.avatarUrl;
    if (avatarUrl == null || avatarUrl.trim().isEmpty) return fallback;
    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
