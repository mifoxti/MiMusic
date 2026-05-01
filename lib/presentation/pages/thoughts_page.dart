import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/playlists/data/repositories/local_playlists_repository.dart';
import '../../features/playlists/domain/entities/playlist.dart';
import 'artist_page.dart';
import 'playlist_detail_page.dart';

enum _ThoughtFeed { friends, popular }
enum _ThoughtAttachmentType { track, playlist }

class ThoughtsPage extends StatefulWidget {
  const ThoughtsPage({
    super.key,
    required this.currentUsername,
    this.audioPlayerService,
  });

  final String currentUsername; 
  final AudioPlayerService? audioPlayerService;

  @override
  State<ThoughtsPage> createState() => _ThoughtsPageState();
}

class _ThoughtsPageState extends State<ThoughtsPage> {
  final List<_ThoughtItem> _items = <_ThoughtItem>[];
  _ThoughtFeed _feed = _ThoughtFeed.friends;
  int _overlayDepth = 0;

  @override
  void initState() {
    super.initState();
    _items.addAll(_seedThoughts());
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<_ThoughtItem> _seedThoughts() {
    return [
      _ThoughtItem(
        id: '1',
        author: 'alexwave',
        text:
            'Никто так не спасает вечер, как правильный дроп в наушниках.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        isFriend: true,
        attachment: const _ThoughtAttachment(
          type: _ThoughtAttachmentType.track,
          title: 'Why We Lose',
          subtitle: 'Cartoon',
          trackAssetPath: 'assets/music/Cartoon - Why We Lose - Cartoon.mp3',
        ),
        likesCount: 28,
        comments: const ['Согласен, дроп отличный', 'У меня этот трек в repeat'],
      ),
      _ThoughtItem(
        id: '2',
        author: 'nightcore_anna',
        text: 'Собрала плейлист для ночной поездки по городу.',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        isFriend: true,
        attachment: const _ThoughtAttachment(
          type: _ThoughtAttachmentType.playlist,
          title: 'Night Drive',
          subtitle: '12 треков',
          playlistId: 'seed-night-drive',
        ),
        likesCount: 34,
        comments: const ['Кинь ссылку на плейлист', 'Топ для вечерних поездок'],
      ),
      _ThoughtItem(
        id: '3',
        author: 'synthfox',
        text: 'Лучший момент трека начинается после второго припева.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isFriend: false,
        attachment: const _ThoughtAttachment(
          type: _ThoughtAttachmentType.track,
          title: 'Lost Control',
          subtitle: 'Gotarux',
          trackAssetPath: 'assets/music/Gotarux - Lost Control.mp3',
        ),
        likesCount: 17,
        comments: const ['Этот синт просто космос'],
      ),
    ];
  }

  Future<void> _openCreateThoughtDialog() async {
    final controller = TextEditingController();
    _ThoughtAttachment? pendingAttachment;
    _overlayDepth++;
    final created = await showDialog<_ComposeResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (dialogContext) {
        final palette = AppPaletteExtension.of(dialogContext).palette;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.cardBackground.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
                  border: Border.all(
                    color: palette.textPrimary.withValues(alpha: 0.16),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('thoughts.new'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: context.t('thoughts.placeholder'),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (pendingAttachment != null) ...[
                      _DraftAttachmentView(
                        attachment: pendingAttachment!,
                        onRemove: () => setDialogState(() => pendingAttachment = null),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final type = await _showAttachmentTypePicker(dialogContext);
                            if (!dialogContext.mounted) return;
                            if (type == _ThoughtAttachmentType.track) {
                              final picked = await _pickTrackAttachment(dialogContext);
                              if (!dialogContext.mounted) return;
                              if (picked != null) {
                                setDialogState(() => pendingAttachment = picked);
                              }
                            } else if (type == _ThoughtAttachmentType.playlist) {
                              final picked = await _pickPlaylistAttachment(dialogContext);
                              if (!dialogContext.mounted) return;
                              if (picked != null) {
                                setDialogState(() => pendingAttachment = picked);
                              }
                            }
                          },
                          icon: const Icon(Icons.attach_file_rounded),
                          label: Text(context.t('thoughts.attach')),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: context.t('common.cancel'),
                            ),
                            const SizedBox(width: 4),
                            FilledButton(
                              onPressed: () {
                                final text = controller.text.trim();
                                if (text.isEmpty) return;
                                Navigator.of(dialogContext).pop(
                                  _ComposeResult(
                                    text: text,
                                    attachment: pendingAttachment,
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(44, 44),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Icon(Icons.arrow_upward_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        );
      },
    );
    _overlayDepth = max(0, _overlayDepth - 1);
    if (!mounted || created == null) return;
    setState(() {
      _items.insert(
        0,
        _ThoughtItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          author: widget.currentUsername,
          text: created.text,
          createdAt: DateTime.now(),
          isFriend: true,
          attachment: created.attachment,
          likesCount: 0,
          comments: const [],
        ),
      );
      _feed = _ThoughtFeed.friends;
    });
    // Защита от assert в активных TextInput-зависимостях:
    // освобождаем контроллер после завершения закрытия диалога.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  Future<_ThoughtAttachmentType?> _showAttachmentTypePicker(BuildContext ownerContext) {
    _overlayDepth++;
    return showModalBottomSheet<_ThoughtAttachmentType?>(
      context: ownerContext,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final palette = AppPaletteExtension.of(sheetContext).palette;
        final media = MediaQuery.of(sheetContext);
        final bottomInset = media.viewInsets.bottom > 0
            ? media.viewInsets.bottom + 8
            : max(
                AppConstants.shellBottomInset - 28,
                media.padding.bottom + 8,
              );
        return SafeArea(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXLarge),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
            padding: EdgeInsets.only(
              bottom: bottomInset,
            ),
            decoration: BoxDecoration(
              color: palette.cardBackground.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusXLarge),
              ),
                  border: Border.all(
                    color: palette.textPrimary.withValues(alpha: 0.12),
                  ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.music_note_rounded),
                  title: Text(context.t('thoughts.attachTrack')),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_ThoughtAttachmentType.track),
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_play_rounded),
                  title: Text(context.t('thoughts.attachPlaylist')),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_ThoughtAttachmentType.playlist),
                ),
                ListTile(
                  leading: const Icon(Icons.close_rounded),
                  title: Text(context.t('thoughts.withoutAttachment')),
                  onTap: () => Navigator.of(sheetContext).pop(null),
                ),
              ],
            ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() => _overlayDepth = max(0, _overlayDepth - 1));
  }

  Future<_ThoughtAttachment?> _pickTrackAttachment(BuildContext ownerContext) async {
    final tracks = await loadLocalTracks();
    if (!mounted || tracks.isEmpty) return null;
    if (!ownerContext.mounted) return null;
    final likedPaths = widget.audioPlayerService?.likedPaths ?? <String>{};
    final likedTracks =
        tracks.where((t) => likedPaths.contains(t.assetPath)).toList();
    final searchController = TextEditingController();
    _overlayDepth++;
    final selected = await showModalBottomSheet<Track>(
      context: ownerContext,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final palette = AppPaletteExtension.of(sheetContext).palette;
        final media = MediaQuery.of(sheetContext);
        final bottomInset = media.viewInsets.bottom > 0
            ? media.viewInsets.bottom + 8
            : max(
                AppConstants.shellBottomInset - 28,
                media.padding.bottom + 8,
              );
        var showLiked = true;
        var query = '';
        List<Track> filtered(List<Track> source) {
          if (query.trim().isEmpty) return source;
          final q = query.toLowerCase();
          return source
              .where(
                (t) =>
                    t.title.toLowerCase().contains(q) ||
                    t.artistDisplay.toLowerCase().contains(q),
              )
              .toList();
        }
        return SafeArea(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXLarge),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  final source = showLiked ? likedTracks : tracks;
                  final data = filtered(source);
                  return Container(
                    decoration: BoxDecoration(
                      color: palette.cardBackground.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppConstants.radiusXLarge),
                      ),
                      border: Border.all(
                        color: palette.textPrimary.withValues(alpha: 0.12),
                      ),
                    ),
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Liked'),
                            selected: showLiked,
                            onSelected: (_) => setSheetState(() => showLiked = true),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('All'),
                            selected: !showLiked,
                            onSelected: (_) => setSheetState(() => showLiked = false),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: (v) => setSheetState(() => query = v),
                        decoration: InputDecoration(
                          hintText: context.t('common.search'),
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: palette.cardBackground.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: data.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(context.t('search.notFound')),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: data.length,
                              itemBuilder: (context, index) {
                                final t = data[index];
                                return ListTile(
                                  title: Text(t.title),
                                  subtitle: Text(
                                    t.artistDisplay.isEmpty
                                        ? 'Unknown artist'
                                        : t.artistDisplay,
                                  ),
                                  onTap: () => Navigator.of(sheetContext).pop(t),
                                );
                              },
                            ),
                    ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      _overlayDepth = max(0, _overlayDepth - 1);
    });
    if (selected == null) return null;
    return _ThoughtAttachment(
      type: _ThoughtAttachmentType.track,
      title: selected.title,
      subtitle:
          selected.artistDisplay.isEmpty ? 'Unknown artist' : selected.artistDisplay,
      trackAssetPath: selected.assetPath,
    );
  }

  Future<_ThoughtAttachment?> _pickPlaylistAttachment(BuildContext ownerContext) async {
    final repo = LocalPlaylistsRepository();
    final playlists = await repo.getPlaylists();
    if (!mounted) return null;
    if (playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a playlist first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }
    if (!ownerContext.mounted) return null;
    _overlayDepth++;
    final selected = await showModalBottomSheet<Playlist>(
      context: ownerContext,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final palette = AppPaletteExtension.of(sheetContext).palette;
        final media = MediaQuery.of(sheetContext);
        final bottomInset = media.viewInsets.bottom > 0
            ? media.viewInsets.bottom + 8
            : max(
                AppConstants.shellBottomInset - 28,
                media.padding.bottom + 8,
              );
        return SafeArea(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXLarge),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.cardBackground.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppConstants.radiusXLarge),
                  ),
                  border: Border.all(
                    color: palette.textPrimary.withValues(alpha: 0.12),
                  ),
                ),
                padding: EdgeInsets.only(bottom: bottomInset),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final p = playlists[index];
                    return ListTile(
                      title: Text(p.title),
                      subtitle: Text('${p.trackAssetPaths.length} tracks'),
                      onTap: () => Navigator.of(sheetContext).pop(p),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() => _overlayDepth = max(0, _overlayDepth - 1));
    if (selected == null) return null;
    return _ThoughtAttachment(
      type: _ThoughtAttachmentType.playlist,
      title: selected.title,
      subtitle: '${selected.trackAssetPaths.length} tracks',
      playlistId: selected.id,
    );
  }

  Future<void> _openAttachment(_ThoughtAttachment attachment) async {
    if (attachment.type == _ThoughtAttachmentType.track) {
      final path = attachment.trackAssetPath;
      if (path == null || widget.audioPlayerService == null) return;
      final tracks = await loadLocalTracks();
      final idx = tracks.indexWhere((t) => t.assetPath == path);
      if (idx < 0) return;
      final track = tracks[idx];
      await widget.audioPlayerService!.playTrack(track, queue: tracks);
      return;
    }
    if (attachment.type == _ThoughtAttachmentType.playlist) {
      if (!mounted) return;
      final repo = LocalPlaylistsRepository();
      var id = attachment.playlistId;
      if (id == null || id.isEmpty) {
        final all = await repo.getPlaylists();
        if (!mounted) return;
        final matched = all.where((p) => p.title == attachment.title).toList();
        if (matched.isEmpty) return;
        id = matched.first.id;
      }
      if (id.isEmpty) return;
      final resolvedId = id;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaylistDetailPage(
            playlistId: resolvedId,
            repository: repo,
          ),
        ),
      );
    }
  }

  void _toggleLike(String thoughtId) {
    final index = _items.indexWhere((e) => e.id == thoughtId);
    if (index < 0) return;
    final item = _items[index];
    final liked = !item.likedByMe;
    setState(() {
      _items[index] = item.copyWith(
        likedByMe: liked,
        likesCount: liked ? item.likesCount + 1 : max(0, item.likesCount - 1),
      );
    });
  }

  Future<void> _openComments(String thoughtId) async {
    final index = _items.indexWhere((e) => e.id == thoughtId);
    if (index < 0) return;
    final palette = AppPaletteExtension.of(context).palette;
    final controller = TextEditingController();
    _overlayDepth++;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final bottomInset = media.viewInsets.bottom > 0
            ? media.viewInsets.bottom + 8
            : max(
                AppConstants.shellBottomInset - 28,
                media.padding.bottom + 8,
              );
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final item = _items[index];
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusXLarge),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: EdgeInsets.fromLTRB(14, 12, 14, bottomInset),
                  decoration: BoxDecoration(
                    color: palette.cardBackground.withValues(alpha: 0.72),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppConstants.radiusXLarge),
                    ),
                    border: Border.all(
                      color: palette.textPrimary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('thoughts.comments'),
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: item.comments.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  context.t('thoughts.noComments'),
                                  style: TextStyle(color: palette.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: item.comments.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, i) => Text(
                                  '• ${item.comments[i]}',
                                  style: TextStyle(color: palette.textPrimary),
                                ),
                              ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              decoration: InputDecoration(
                                hintText: context.t('thoughts.addComment'),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              final text = controller.text.trim();
                              if (text.isEmpty) return;
                              setState(() {
                                final current = _items[index];
                                _items[index] = current.copyWith(
                                  comments: [...current.comments, text],
                                );
                              });
                              controller.clear();
                              setSheetState(() {});
                            },
                            child: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    _overlayDepth = max(0, _overlayDepth - 1);
  }

  Future<void> _openAuthorProfile(String username) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArtistPage(
          artistName: username,
          audioPlayerService: widget.audioPlayerService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final items = _items
        .where((e) => _feed == _ThoughtFeed.popular ? true : e.isFriend)
        .toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.gradientStart.withValues(alpha: 0.95),
            palette.accent.withValues(alpha: 0.26),
            palette.gradientMiddle,
            palette.gradientEnd,
          ],
          stops: const [0.0, 0.22, 0.58, 1.0],
        ),
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_overlayDepth > 0) {
            Navigator.of(context, rootNavigator: true).maybePop();
            return;
          }
          Navigator.of(context).pop();
        },
        child: widget.audioPlayerService == null
            ? _ThoughtsScaffoldBody(
                palette: palette,
                items: items,
                feed: _feed,
                onFeedChanged: (f) => setState(() => _feed = f),
                onAttachmentTap: _openAttachment,
                onLikeTap: _toggleLike,
                onCommentTap: _openComments,
                onAuthorTap: _openAuthorProfile,
                onCreateTap: _openCreateThoughtDialog,
                fabBottomInset: AppConstants.shellBottomInset,
              )
            : ListenableBuilder(
                listenable: widget.audioPlayerService!,
                builder: (context, _) {
            final hasMiniPlayer = widget.audioPlayerService?.currentTrack != null;
            final fabBottomInset = hasMiniPlayer
                ? AppConstants.shellBottomInsetWithMiniPlayer
                : AppConstants.shellBottomInset;
            return _ThoughtsScaffoldBody(
              palette: palette,
              items: items,
              feed: _feed,
              onFeedChanged: (f) => setState(() => _feed = f),
              onAttachmentTap: _openAttachment,
              onLikeTap: _toggleLike,
              onCommentTap: _openComments,
              onAuthorTap: _openAuthorProfile,
              onCreateTap: _openCreateThoughtDialog,
              fabBottomInset: fabBottomInset,
            );
          },
        ),
      ),
    );
  }
}

class _ThoughtsScaffoldBody extends StatelessWidget {
  const _ThoughtsScaffoldBody({
    required this.palette,
    required this.items,
    required this.feed,
    required this.onFeedChanged,
    required this.onAttachmentTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onAuthorTap,
    required this.onCreateTap,
    required this.fabBottomInset,
  });

  final AppColorPalette palette;
  final List<_ThoughtItem> items;
  final _ThoughtFeed feed;
  final ValueChanged<_ThoughtFeed> onFeedChanged;
  final ValueChanged<_ThoughtAttachment> onAttachmentTap;
  final ValueChanged<String> onLikeTap;
  final ValueChanged<String> onCommentTap;
  final ValueChanged<String> onAuthorTap;
  final VoidCallback onCreateTap;
  final double fabBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabBottomInset),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: FloatingActionButton(
              onPressed: onCreateTap,
              backgroundColor: palette.cardBackground.withValues(alpha: 0.52),
              foregroundColor: palette.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: palette.textPrimary.withValues(alpha: 0.15),
                ),
              ),
              child: const Icon(Icons.add_rounded, size: 30),
            ),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(context.t('thoughts.title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: _FeedSwitch(
              feed: feed,
              onChanged: onFeedChanged,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _ThoughtCard(
                  item: items[index],
                  onAttachmentTap: onAttachmentTap,
                  onLikeTap: () => onLikeTap(items[index].id),
                  onCommentTap: () => onCommentTap(items[index].id),
                  onAuthorTap: () => onAuthorTap(items[index].author),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedSwitch extends StatelessWidget {
  const _FeedSwitch({
    required this.feed,
    required this.onChanged,
  });

  final _ThoughtFeed feed;
  final ValueChanged<_ThoughtFeed> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FeedChip(
              selected: feed == _ThoughtFeed.friends,
              label: context.t('thoughts.friends'),
              onTap: () => onChanged(_ThoughtFeed.friends),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _FeedChip(
              selected: feed == _ThoughtFeed.popular,
              label: context.t('thoughts.popular'),
              onTap: () => onChanged(_ThoughtFeed.popular),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedChip extends StatelessWidget {
  const _FeedChip({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Material(
      color: selected ? palette.accent.withValues(alpha: 0.24) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge - 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge - 2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThoughtCard extends StatelessWidget {
  const _ThoughtCard({
    required this.item,
    required this.onAttachmentTap,
    required this.onLikeTap,
    required this.onCommentTap,
    required this.onAuthorTap,
  });

  final _ThoughtItem item;
  final ValueChanged<_ThoughtAttachment> onAttachmentTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final VoidCallback onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final initial = item.author.isNotEmpty ? item.author[0].toUpperCase() : '?';
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.cardBackground.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: palette.textPrimary.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: onAuthorTap,
                    borderRadius: BorderRadius.circular(26),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: palette.accent.withValues(alpha: 0.24),
                          child: Text(initial),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${item.author}',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _relative(context, item.createdAt),
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.text,
                style: TextStyle(
                  color: palette.textPrimary,
                  height: 1.3,
                ),
              ),
              if (item.attachment != null) ...[
                const SizedBox(height: 12),
                _AttachmentCard(
                  attachment: item.attachment!,
                  onTap: () => onAttachmentTap(item.attachment!),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  InkWell(
                    onTap: onLikeTap,
                    child: Icon(
                      item.likedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: item.likedByMe ? palette.accent : palette.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.likesCount}',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: onCommentTap,
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item.comments.length}',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relative(BuildContext context, DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (diff.inMinutes < 1) return isEn ? 'just now' : 'только что';
    if (diff.inMinutes < 60) {
      return isEn ? '${diff.inMinutes} min ago' : '${diff.inMinutes} мин назад';
    }
    if (diff.inHours < 24) {
      return isEn ? '${diff.inHours} h ago' : '${diff.inHours} ч назад';
    }
    return isEn ? '${diff.inDays} d ago' : '${diff.inDays} д назад';
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.onTap,
  });

  final _ThoughtAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: palette.primaryDark.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
          child: Row(
            children: [
              Icon(
                attachment.type == _ThoughtAttachmentType.track
                    ? Icons.music_note_rounded
                    : Icons.playlist_play_rounded,
                color: palette.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((attachment.subtitle ?? '').isNotEmpty)
                      Text(
                        attachment.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DraftAttachmentView extends StatelessWidget {
  const _DraftAttachmentView({
    required this.attachment,
    required this.onRemove,
  });

  final _ThoughtAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.primaryLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            attachment.type == _ThoughtAttachmentType.track
                ? Icons.music_note_rounded
                : Icons.playlist_play_rounded,
            color: palette.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ComposeResult {
  const _ComposeResult({
    required this.text,
    this.attachment,
  });

  final String text;
  final _ThoughtAttachment? attachment;
}

class _ThoughtItem {
  const _ThoughtItem({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.isFriend,
    required this.likesCount,
    required this.comments,
    this.likedByMe = false,
    this.attachment,
  });

  final String id;
  final String author;
  final String text;
  final DateTime createdAt;
  final bool isFriend;
  final int likesCount;
  final List<String> comments;
  final bool likedByMe;
  final _ThoughtAttachment? attachment;

  _ThoughtItem copyWith({
    int? likesCount,
    List<String>? comments,
    bool? likedByMe,
  }) {
    return _ThoughtItem(
      id: id,
      author: author,
      text: text,
      createdAt: createdAt,
      isFriend: isFriend,
      attachment: attachment,
      likesCount: likesCount ?? this.likesCount,
      comments: comments ?? this.comments,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

class _ThoughtAttachment {
  const _ThoughtAttachment({
    required this.type,
    required this.title,
    this.subtitle,
    this.trackAssetPath,
    this.playlistId,
  });

  final _ThoughtAttachmentType type;
  final String title;
  final String? subtitle;
  final String? trackAssetPath;
  final String? playlistId;
}
