import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_bottom_menu_sheet.dart';
import '../widgets/hold_to_confirm_button.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/network/api_config.dart';
import '../../core/network/playlists_api.dart';
import '../../core/network/thoughts_api.dart';
import '../../core/network/tracks_api.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/widgets/cover_image.dart';
import 'playlist_detail_page.dart';
import 'user_public_profile_page.dart';

enum _ThoughtFeed { friends, popular }
enum _ThoughtAttachmentType { track, playlist }

class ThoughtsPage extends StatefulWidget {
  const ThoughtsPage({
    super.key,
    required this.currentUsername,
    this.audioPlayerService,
    this.viewedUserId,
    this.viewedUserNickname,
  });

  final String currentUsername;
  final AudioPlayerService? audioPlayerService;

  /// Если задан — лента одной последней мысли этого пользователя с сервера ([GET /users/{id}/thought]).
  final int? viewedUserId;
  final String? viewedUserNickname;

  @override
  State<ThoughtsPage> createState() => _ThoughtsPageState();
}

class _ThoughtsPageState extends State<ThoughtsPage> {
  final List<_ThoughtItem> _items = <_ThoughtItem>[];
  _ThoughtFeed _feed = _ThoughtFeed.friends;
  int _overlayDepth = 0;
  final Set<String> _expandedComments = <String>{};
  final Set<String> _commentsLoaded = <String>{};
  final Set<String> _commentsLoading = <String>{};
  final Map<String, TextEditingController> _commentControllers =
      <String, TextEditingController>{};
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentUserId());
    if (widget.viewedUserId != null) {
      unawaited(_loadUserThoughtsList());
    } else {
      unawaited(_loadFeed());
    }
  }

  Future<void> _loadCurrentUserId() async {
    final acc = await AuthSessionStore.readAccount();
    if (!mounted) return;
    setState(() => _currentUserId = acc?.userId);
  }

  _ThoughtItem _fromDto(ThoughtFeedItemDto dto) {
    _ThoughtAttachment? att;
    final at = dto.attachmentType;
    if (at == 1 && dto.attachmentTrackId != null) {
      final tid = dto.attachmentTrackId!;
      att = _ThoughtAttachment(
        type: _ThoughtAttachmentType.track,
        title: (dto.attachmentTrackTitle ?? '').trim().isEmpty ? '—' : dto.attachmentTrackTitle!.trim(),
        subtitle: (dto.attachmentTrackArtist ?? '').trim().isEmpty ? null : dto.attachmentTrackArtist!.trim(),
        trackAssetPath: 'server_track_$tid',
        serverTrackId: tid,
      );
    } else if (at == 2 && dto.attachmentPlaylistId != null) {
      final pid = dto.attachmentPlaylistId!;
      att = _ThoughtAttachment(
        type: _ThoughtAttachmentType.playlist,
        title: (dto.attachmentPlaylistTitle ?? '').trim().isEmpty ? '—' : dto.attachmentPlaylistTitle!.trim(),
        subtitle: null,
        playlistId: 'srv:$pid',
      );
    }
    final ts = dto.createdAt;
    return _ThoughtItem(
      id: dto.id.toString(),
      authorUserId: dto.authorUserId,
      author: dto.authorNickname,
      text: (dto.bodyText ?? '').trim(),
      createdAt: DateTime.tryParse(ts ?? '') ?? DateTime.now(),
      isFriend: dto.isFriend,
      attachment: att,
      likesCount: dto.likesCount,
      likedByMe: dto.likedByMe,
      commentsCount: dto.commentsCount,
      comments: const [],
    );
  }

  _ThoughtComment _commentFromDto(ThoughtCommentDto dto) {
    return _ThoughtComment(
      id: dto.id.toString(),
      authorUserId: dto.authorUserId,
      author: dto.authorNickname,
      text: (dto.bodyText ?? '').trim(),
      createdAt: DateTime.tryParse(dto.createdAt ?? '') ?? DateTime.now(),
    );
  }

  Future<void> _loadFeed() async {
    try {
      final scope = _feed == _ThoughtFeed.friends ? 'friends' : 'popular';
      final list = await ThoughtsApi().fetchThoughtFeed(scope: scope);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list.map(_fromDto));
        _commentsLoaded.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items.clear();
        _commentsLoaded.clear();
      });
    }
  }

  Future<void> _loadUserThoughtsList() async {
    final id = widget.viewedUserId;
    if (id == null) return;
    try {
      final list = await ThoughtsApi().fetchUserThoughts(id);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(list.map(_fromDto));
        _commentsLoaded.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items.clear();
        _commentsLoaded.clear();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _commentControllerFor(String thoughtId) {
    return _commentControllers.putIfAbsent(
      thoughtId,
      TextEditingController.new,
    );
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
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('friends.loginToFriend'))),
      );
      return;
    }
    int? attachType;
    int? attachTrack;
    int? attachPlaylist;
    final a = created.attachment;
    if (a != null) {
      if (a.type == _ThoughtAttachmentType.track && a.serverTrackId != null) {
        attachType = 1;
        attachTrack = a.serverTrackId;
      } else if (a.type == _ThoughtAttachmentType.playlist) {
        final sid = parseServerPlaylistId(a.playlistId ?? '');
        if (sid != null) {
          attachType = 2;
          attachPlaylist = sid;
        }
      }
    }
    try {
      final dto = await ThoughtsApi().createThought(
        bodyText: created.text,
        attachmentType: attachType,
        attachmentTrackId: attachTrack,
        attachmentPlaylistId: attachPlaylist,
      );
      if (!mounted) return;
      setState(() {
        _items.insert(0, _fromDto(dto));
        _feed = _ThoughtFeed.friends;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('thoughts.postFailed'))),
      );
    }
    // Защита от assert в активных TextInput-зависимостях:
    // освобождаем контроллер после завершения закрытия диалога.
    // Ничего: принудительный dispose здесь может падать assertion'ом
    // (`_dependents.isEmpty`) при закрытии вложенных bottom-sheet/dialog.
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
    if (!ownerContext.mounted) return null;
    List<ServerTrackListItem> serverTracks;
    try {
      serverTracks = await TracksApi().fetchTracks(limit: 500);
    } catch (_) {
      serverTracks = [];
    }
    if (!mounted) return null;
    if (serverTracks.isEmpty) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('thoughts.noServerTracks'))),
      );
      return null;
    }
    final searchController = TextEditingController();
    _overlayDepth++;
    var query = '';
    List<ServerTrackListItem> filtered() {
      if (query.trim().isEmpty) return serverTracks;
      final q = query.toLowerCase();
      return serverTracks
          .where(
            (t) =>
                t.title.toLowerCase().contains(q) ||
                (t.artist ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
    final selected = await showModalBottomSheet<ServerTrackListItem>(
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
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  final data = filtered();
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
                        SizedBox(
                          height: min(420.0, MediaQuery.of(sheetContext).size.height * 0.55),
                          child: data.isEmpty
                              ? Center(child: Text(context.t('search.notFound')))
                              : ListView.builder(
                                  itemCount: data.length,
                                  itemBuilder: (context, index) {
                                    final t = data[index];
                                    return ListTile(
                                      title: Text(t.title),
                                      subtitle: Text(
                                        (t.artist ?? '').trim().isEmpty
                                            ? context.t('thoughts.unknownArtist')
                                            : t.artist!,
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
      subtitle: (selected.artist ?? '').trim().isEmpty ? null : selected.artist,
      trackAssetPath: 'server_track_${selected.id}',
      serverTrackId: selected.id,
    );
  }

  Future<_ThoughtAttachment?> _pickPlaylistAttachment(BuildContext ownerContext) async {
    final tracksWord = context.t('userProfile.tracksWord');
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('friends.loginToFriend'))),
      );
      return null;
    }
    if (!ownerContext.mounted) return null;
    List<MyPlaylistListItemRemote> rows;
    try {
      rows = await PlaylistsApi().fetchMyPlaylists();
    } catch (_) {
      rows = [];
    }
    if (!mounted) return null;
    if (rows.isEmpty) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('thoughts.noPlaylistsForAttach'))),
      );
      return null;
    }
    _overlayDepth++;
    final selected = await showModalBottomSheet<MyPlaylistListItemRemote>(
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
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final p = rows[index];
                    final title = (p.title ?? '').trim().isEmpty ? '—' : p.title!.trim();
                    return ListTile(
                      title: Text(title),
                      subtitle: Text('${p.trackCount} $tracksWord'),
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
    final title = (selected.title ?? '').trim().isEmpty ? '—' : selected.title!.trim();
    return _ThoughtAttachment(
      type: _ThoughtAttachmentType.playlist,
      title: title,
      subtitle: '${selected.trackCount} $tracksWord',
      playlistId: 'srv:${selected.id}',
    );
  }

  Future<void> _openAttachment(_ThoughtAttachment attachment) async {
    if (attachment.type == _ThoughtAttachmentType.track) {
      if (widget.audioPlayerService == null) return;
      final sid = attachment.serverTrackId ??
          TracksApi().parseServerTrackId(attachment.trackAssetPath ?? '');
      if (sid == null) return;
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final track = Track(
        assetPath: 'server_track_$sid',
        title: attachment.title,
        artist: attachment.subtitle,
        audioFilePath: '$base/tracks/$sid/stream',
        coverAssetPath: '$base/tracks/$sid/cover',
      );
      await widget.audioPlayerService!.playTrack(track, queue: [track]);
      return;
    }
    if (attachment.type == _ThoughtAttachmentType.playlist) {
      if (!mounted) return;
      final id = attachment.playlistId;
      if (id == null || id.isEmpty || widget.audioPlayerService == null) return;
      await Navigator.of(context).push(
        ShellMaterialPageRoute<void>(
          builder: (_) => PlaylistDetailPage(
            playlistId: id,
            audioPlayerService: widget.audioPlayerService!,
          ),
        ),
      );
    }
  }

  Future<void> _toggleLike(String thoughtId) async {
    final index = _items.indexWhere((e) => e.id == thoughtId);
    if (index < 0) return;
    final tid = int.tryParse(thoughtId);
    if (tid == null) return;
    try {
      final result = await ThoughtsApi().toggleThoughtLike(tid);
      if (!mounted) return;
      final item = _items[index];
      setState(() {
        _items[index] = item.copyWith(
          likedByMe: result.liked,
          likesCount: result.likesCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  Future<void> _toggleComments(String thoughtId) async {
    final expanding = !_expandedComments.contains(thoughtId);
    setState(() {
      if (expanding) {
        _expandedComments.add(thoughtId);
      } else {
        _expandedComments.remove(thoughtId);
      }
    });
    if (!expanding) return;
    final index = _items.indexWhere((e) => e.id == thoughtId);
    if (index < 0) return;
    final item = _items[index];
    final commentsStale = _commentsLoaded.contains(thoughtId) &&
        item.commentsCount != item.comments.length;
    if (_commentsLoaded.contains(thoughtId) && !commentsStale) return;
    if (commentsStale) _commentsLoaded.remove(thoughtId);
    final tid = int.tryParse(thoughtId);
    if (tid == null) return;
    setState(() => _commentsLoading.add(thoughtId));
    try {
      final list = await ThoughtsApi().fetchThoughtComments(tid);
      if (!mounted) return;
      final loadedIndex = _items.indexWhere((e) => e.id == thoughtId);
      if (loadedIndex >= 0) {
        setState(() {
          _items[loadedIndex] = _items[loadedIndex].copyWith(
            comments: list.map(_commentFromDto).toList(),
            commentsCount: list.length,
          );
          _commentsLoaded.add(thoughtId);
          _commentsLoading.remove(thoughtId);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _commentsLoading.remove(thoughtId);
        _commentsLoaded.remove(thoughtId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  Future<void> _addComment(String thoughtId) async {
    final index = _items.indexWhere((e) => e.id == thoughtId);
    if (index < 0) return;
    final controller = _commentControllerFor(thoughtId);
    final text = controller.text.trim();
    if (text.isEmpty) return;
    final tid = int.tryParse(thoughtId);
    if (tid == null) return;
    try {
      final created = await ThoughtsApi().postThoughtComment(
        thoughtId: tid,
        bodyText: text,
      );
      if (!mounted) return;
      final current = _items[index];
      setState(() {
        _items[index] = current.copyWith(
          comments: [...current.comments, _commentFromDto(created)],
          commentsCount: current.commentsCount + 1,
        );
        _commentsLoaded.add(thoughtId);
        _expandedComments.add(thoughtId);
        controller.clear();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  Future<void> _showCommentManageSheet(
    String thoughtId,
    _ThoughtComment comment,
  ) async {
    _overlayDepth++;
    await showGlassBottomMenuSheet(
      context,
      actions: [
        GlassMenuAction(
          icon: Icons.edit_rounded,
          label: context.t('thoughts.edit'),
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              unawaited(_editComment(thoughtId, comment));
            });
          },
        ),
        GlassMenuAction(
          icon: Icons.delete_outline_rounded,
          label: context.t('thoughts.delete'),
          iconColor: Colors.redAccent,
          labelStyle: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              unawaited(_deleteComment(thoughtId, comment));
            });
          },
        ),
      ],
    );
    _overlayDepth = max(0, _overlayDepth - 1);
  }

  Future<void> _editComment(String thoughtId, _ThoughtComment comment) async {
    _overlayDepth++;
    final updatedText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      builder: (sheetContext) {
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _CommentEditSheet(initialText: comment.text),
          ),
        );
      },
    );
    _overlayDepth = max(0, _overlayDepth - 1);
    if (updatedText == null || !mounted) return;
    final thoughtIndex = _items.indexWhere((e) => e.id == thoughtId);
    if (thoughtIndex < 0) return;
    final tid = int.tryParse(thoughtId);
    final cid = int.tryParse(comment.id);
    if (tid == null || cid == null) return;
    try {
      final dto = await ThoughtsApi().updateThoughtComment(
        thoughtId: tid,
        commentId: cid,
        bodyText: updatedText,
      );
      if (!mounted) return;
      final updated = _commentFromDto(dto);
      final item = _items[thoughtIndex];
      setState(() {
        _items[thoughtIndex] = item.copyWith(
          comments: item.comments
              .map((c) => c.id == comment.id ? updated : c)
              .toList(),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('thoughts.commentEditFailed'))),
      );
    }
  }

  Future<void> _deleteComment(String thoughtId, _ThoughtComment comment) async {
    _overlayDepth++;
    final confirmed = await showGlassCenterSheet<bool>(
      context,
      builder: (sheetContext) {
        final palette = AppPaletteExtension.of(sheetContext).palette;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t('thoughts.delete'),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.t('thoughts.commentDeleteConfirm'),
                style: TextStyle(
                  color: palette.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('thoughts.deleteHoldHint'),
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: Text(context.t('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HoldToConfirmButton(
                      label: context.t('thoughts.delete'),
                      onConfirmed: () => Navigator.pop(sheetContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    _overlayDepth = max(0, _overlayDepth - 1);
    if (confirmed != true || !mounted) return;
    final thoughtIndex = _items.indexWhere((e) => e.id == thoughtId);
    if (thoughtIndex < 0) return;
    final tid = int.tryParse(thoughtId);
    final cid = int.tryParse(comment.id);
    if (tid == null || cid == null) return;
    try {
      await ThoughtsApi().deleteThoughtComment(
        thoughtId: tid,
        commentId: cid,
      );
      if (!mounted) return;
      final item = _items[thoughtIndex];
      setState(() {
        _items[thoughtIndex] = item.copyWith(
          comments: item.comments.where((c) => c.id != comment.id).toList(),
          commentsCount: max(0, item.commentsCount - 1),
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('thoughts.commentDeleteFailed'))),
      );
    }
  }

  Future<void> _showThoughtManageSheet(String thoughtId) async {
    _overlayDepth++;
    await showGlassBottomMenuSheet(
      context,
      actions: [
        GlassMenuAction(
          icon: Icons.edit_rounded,
          label: context.t('thoughts.edit'),
          onTap: () => unawaited(_editThought(thoughtId)),
        ),
        GlassMenuAction(
          icon: Icons.delete_outline_rounded,
          label: context.t('thoughts.delete'),
          iconColor: Colors.redAccent,
          labelStyle: const TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
          onTap: () => unawaited(_deleteThought(thoughtId)),
        ),
      ],
    );
    _overlayDepth = max(0, _overlayDepth - 1);
  }

  Future<void> _editThought(String thoughtId) async {
    final index = _items.indexWhere((e) => e.id == thoughtId);
    if (index < 0) return;
    final item = _items[index];
    final controller = TextEditingController(text: item.text);
    _ThoughtAttachment? pendingAttachment = item.attachment;
    _overlayDepth++;
    final updated = await showModalBottomSheet<_ComposeResult>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      builder: (sheetContext) {
        final palette = AppPaletteExtension.of(sheetContext).palette;
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: StatefulBuilder(
              builder: (context, setDialogState) => ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Material(
                    color: palette.cardBackground.withValues(alpha: 0.55),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusXLarge),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusXLarge),
                        border: Border.all(
                          color: palette.textPrimary.withValues(alpha: 0.16),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('thoughts.edit'),
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
                                onRemove: () => setDialogState(
                                  () => pendingAttachment = null,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    final type = await _showAttachmentTypePicker(
                                      sheetContext,
                                    );
                                    if (!sheetContext.mounted) return;
                                    if (type == _ThoughtAttachmentType.track) {
                                      final picked = await _pickTrackAttachment(
                                        sheetContext,
                                      );
                                      if (!sheetContext.mounted) return;
                                      if (picked != null) {
                                        setDialogState(
                                          () => pendingAttachment = picked,
                                        );
                                      }
                                    } else if (type ==
                                        _ThoughtAttachmentType.playlist) {
                                      final picked =
                                          await _pickPlaylistAttachment(
                                        sheetContext,
                                      );
                                      if (!sheetContext.mounted) return;
                                      if (picked != null) {
                                        setDialogState(
                                          () => pendingAttachment = picked,
                                        );
                                      }
                                    } else if (type == null) {
                                      setDialogState(
                                        () => pendingAttachment = null,
                                      );
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
                                      onPressed: () =>
                                          Navigator.of(sheetContext).pop(),
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: context.t('common.cancel'),
                                    ),
                                    const SizedBox(width: 4),
                                    FilledButton(
                                      onPressed: () {
                                        final text = controller.text.trim();
                                        if (text.isEmpty) return;
                                        Navigator.of(sheetContext).pop(
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
                                      child: const Icon(Icons.check_rounded),
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
              ),
            ),
          ),
        );
      },
    );
    _overlayDepth = max(0, _overlayDepth - 1);
    if (updated == null || !mounted) return;
    final tid = int.tryParse(thoughtId);
    if (tid == null) return;
    int attachType = 0;
    int? attachTrack;
    int? attachPlaylist;
    final a = updated.attachment;
    if (a != null) {
      if (a.type == _ThoughtAttachmentType.track && a.serverTrackId != null) {
        attachType = 1;
        attachTrack = a.serverTrackId;
      } else if (a.type == _ThoughtAttachmentType.playlist) {
        final sid = parseServerPlaylistId(a.playlistId ?? '');
        if (sid != null) {
          attachType = 2;
          attachPlaylist = sid;
        }
      }
    }
    try {
      final dto = await ThoughtsApi().updateThought(
        thoughtId: tid,
        bodyText: updated.text,
        attachmentType: attachType,
        attachmentTrackId: attachTrack,
        attachmentPlaylistId: attachPlaylist,
      );
      if (!mounted) return;
      setState(() {
        _items[index] = _fromDto(dto).copyWith(
          comments: item.comments,
          commentsCount: item.commentsCount,
          likedByMe: item.likedByMe,
          likesCount: item.likesCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('thoughts.editFailed'))),
      );
    }
  }

  Future<void> _deleteThought(String thoughtId) async {
    final index = _items.indexWhere((e) => e.id == thoughtId);
    if (index < 0) return;
    _overlayDepth++;
    final confirmed = await showGlassCenterSheet<bool>(
      context,
      builder: (sheetContext) {
        final palette = AppPaletteExtension.of(sheetContext).palette;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t('thoughts.delete'),
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.t('thoughts.deleteConfirm'),
                style: TextStyle(
                  color: palette.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('thoughts.deleteHoldHint'),
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: Text(context.t('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HoldToConfirmButton(
                      label: context.t('thoughts.delete'),
                      onConfirmed: () => Navigator.pop(sheetContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    _overlayDepth = max(0, _overlayDepth - 1);
    if (confirmed != true || !mounted) return;
    final tid = int.tryParse(thoughtId);
    if (tid == null) return;
    try {
      await ThoughtsApi().deleteThought(tid);
      if (!mounted) return;
      setState(() {
        _items.removeAt(index);
        _expandedComments.remove(thoughtId);
        _commentsLoaded.remove(thoughtId);
        _commentsLoading.remove(thoughtId);
        _commentControllers.remove(thoughtId)?.dispose();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('thoughts.deleteFailed'))),
      );
    }
  }

  Future<void> _openAuthorProfile(int userId, String nickname) async {
    if (!mounted || widget.audioPlayerService == null) return;
    await Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) => UserPublicProfilePage(
          userId: userId,
          nickname: nickname,
          audioPlayerService: widget.audioPlayerService!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final items = List<_ThoughtItem>.from(_items);

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
                onFeedChanged: (f) {
                  setState(() => _feed = f);
                  unawaited(_loadFeed());
                },
                onAttachmentTap: _openAttachment,
                onLikeTap: _toggleLike,
                onCommentTap: _toggleComments,
                isCommentsExpanded: _expandedComments.contains,
                commentControllerFor: _commentControllerFor,
                onCommentSubmit: _addComment,
                onAuthorTap: _openAuthorProfile,
                isCommentsLoading: _commentsLoading.contains,
                onCreateTap: _openCreateThoughtDialog,
                currentUserId: _currentUserId,
                onManageThought: _showThoughtManageSheet,
                onManageComment: _showCommentManageSheet,
                fabBottomInset: AppConstants.shellBottomInset,
                showComposer: widget.viewedUserId == null,
                showFeedSwitch: widget.viewedUserId == null,
                titleOverride: widget.viewedUserId != null
                    ? '${context.t('profile.thoughts')} · @${widget.viewedUserNickname ?? ''}'
                    : null,
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
              onFeedChanged: (f) {
                setState(() => _feed = f);
                unawaited(_loadFeed());
              },
              onAttachmentTap: _openAttachment,
              onLikeTap: _toggleLike,
              onCommentTap: _toggleComments,
              isCommentsExpanded: _expandedComments.contains,
              commentControllerFor: _commentControllerFor,
              onCommentSubmit: _addComment,
              onAuthorTap: _openAuthorProfile,
              isCommentsLoading: _commentsLoading.contains,
              onCreateTap: _openCreateThoughtDialog,
              currentUserId: _currentUserId,
              onManageThought: _showThoughtManageSheet,
              onManageComment: _showCommentManageSheet,
              fabBottomInset: fabBottomInset,
              showComposer: widget.viewedUserId == null,
              showFeedSwitch: widget.viewedUserId == null,
              titleOverride: widget.viewedUserId != null
                  ? '${context.t('profile.thoughts')} · @${widget.viewedUserNickname ?? ''}'
                  : null,
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
    required this.isCommentsExpanded,
    required this.commentControllerFor,
    required this.onCommentSubmit,
    required this.onAuthorTap,
    required this.isCommentsLoading,
    required this.onCreateTap,
    required this.fabBottomInset,
    this.currentUserId,
    this.onManageThought,
    this.onManageComment,
    this.showComposer = true,
    this.showFeedSwitch = true,
    this.titleOverride,
  });

  final AppColorPalette palette;
  final List<_ThoughtItem> items;
  final _ThoughtFeed feed;
  final ValueChanged<_ThoughtFeed> onFeedChanged;
  final ValueChanged<_ThoughtAttachment> onAttachmentTap;
  final Future<void> Function(String thoughtId) onLikeTap;
  final Future<void> Function(String thoughtId) onCommentTap;
  final bool Function(String thoughtId) isCommentsExpanded;
  final TextEditingController Function(String thoughtId) commentControllerFor;
  final Future<void> Function(String thoughtId) onCommentSubmit;
  final void Function(int userId, String nickname) onAuthorTap;
  final bool Function(String thoughtId) isCommentsLoading;
  final VoidCallback onCreateTap;
  final double fabBottomInset;
  final int? currentUserId;
  final Future<void> Function(String thoughtId)? onManageThought;
  final Future<void> Function(String thoughtId, _ThoughtComment comment)? onManageComment;
  final bool showComposer;
  final bool showFeedSwitch;
  final String? titleOverride;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: showComposer
          ? Padding(
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
            )
          : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(titleOverride ?? context.t('thoughts.title')),
      ),
      body: Column(
        children: [
          if (showFeedSwitch)
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
                final item = items[index];
                final canManage =
                    currentUserId != null && item.authorUserId == currentUserId;
                return _ThoughtCard(
                  item: item,
                  onAttachmentTap: onAttachmentTap,
                  onLikeTap: () => onLikeTap(item.id),
                  onCommentTap: () => onCommentTap(item.id),
                  commentsExpanded: isCommentsExpanded(item.id),
                  commentController: commentControllerFor(item.id),
                  onCommentSubmit: () => onCommentSubmit(item.id),
                  onAuthorTap: onAuthorTap,
                  commentsLoading: isCommentsLoading(item.id),
                  canManage: canManage,
                  onManage: canManage && onManageThought != null
                      ? () => onManageThought!(item.id)
                      : null,
                  currentUserId: currentUserId,
                  onManageComment: onManageComment == null
                      ? null
                      : (comment) => onManageComment!(item.id, comment),
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
    required this.commentsExpanded,
    required this.commentController,
    required this.onCommentSubmit,
    required this.onAuthorTap,
    this.commentsLoading = false,
    this.canManage = false,
    this.onManage,
    this.currentUserId,
    this.onManageComment,
  });

  final _ThoughtItem item;
  final ValueChanged<_ThoughtAttachment> onAttachmentTap;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;
  final bool commentsExpanded;
  final TextEditingController commentController;
  final VoidCallback onCommentSubmit;
  final void Function(int userId, String nickname) onAuthorTap;
  final bool commentsLoading;
  final bool canManage;
  final VoidCallback? onManage;
  final int? currentUserId;
  final Future<void> Function(_ThoughtComment comment)? onManageComment;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final avatarUrl = userAvatarUrl(item.authorUserId);
    final commentCount = commentsExpanded ? item.comments.length : item.commentsCount;
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
                    onTap: () => onAuthorTap(item.authorUserId, item.author),
                    borderRadius: BorderRadius.circular(26),
                    child: Row(
                      children: [
                        ClipOval(
                          child: buildCoverImage(
                            imageUrl: avatarUrl,
                            width: 40,
                            height: 40,
                            borderRadius: BorderRadius.circular(20),
                            placeholder: CircleAvatar(
                              radius: 20,
                              backgroundColor: palette.accent.withValues(alpha: 0.24),
                              child: Icon(
                                Icons.person_rounded,
                                color: palette.accent,
                                size: 22,
                              ),
                            ),
                          ),
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
                  if (canManage && onManage != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: palette.textMuted,
                      ),
                      onPressed: onManage,
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
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.likedByMe
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 22,
                            color: item.likedByMe ? palette.accent : palette.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${item.likesCount}',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: onCommentTap,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            commentsExpanded
                                ? Icons.chat_bubble_rounded
                                : Icons.chat_bubble_outline_rounded,
                            size: 22,
                            color: palette.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$commentCount',
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (commentsExpanded) ...[
                const SizedBox(height: 12),
                _InlineCommentsBlock(
                  comments: item.comments,
                  controller: commentController,
                  onSubmit: onCommentSubmit,
                  onAuthorTap: onAuthorTap,
                  loading: commentsLoading,
                  currentUserId: currentUserId,
                  onManageComment: onManageComment,
                ),
              ],
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

class _InlineCommentsBlock extends StatelessWidget {
  const _InlineCommentsBlock({
    required this.comments,
    required this.controller,
    required this.onSubmit,
    required this.onAuthorTap,
    this.loading = false,
    this.currentUserId,
    this.onManageComment,
  });

  final List<_ThoughtComment> comments;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final void Function(int userId, String nickname) onAuthorTap;
  final bool loading;
  final int? currentUserId;
  final Future<void> Function(_ThoughtComment comment)? onManageComment;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(color: palette.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.accent,
                  ),
                ),
              ),
            )
          else if (comments.isEmpty)
            Text(
              context.t('thoughts.noComments'),
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final comment = comments[index];
                final commentAvatar = userAvatarUrl(comment.authorUserId);
                final canManageComment = currentUserId != null &&
                    comment.authorUserId == currentUserId &&
                    onManageComment != null;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipOval(
                      child: buildCoverImage(
                        imageUrl: commentAvatar,
                        width: 28,
                        height: 28,
                        borderRadius: BorderRadius.circular(14),
                        placeholder: Container(
                          width: 28,
                          height: 28,
                          color: palette.accent.withValues(alpha: 0.2),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: palette.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => onAuthorTap(comment.authorUserId, comment.author),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Text(
                                  '@${comment.author}',
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            comment.text,
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 13,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canManageComment)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: palette.textSecondary,
                        ),
                        onPressed: () => onManageComment!(comment),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: context.t('thoughts.addComment'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: onSubmit,
                icon: const Icon(Icons.reply_rounded),
                label: Text(isEn ? 'Reply' : 'Ответить'),
              ),
            ],
          ),
        ],
      ),
    );
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
    required this.authorUserId,
    required this.author,
    required this.text,
    required this.createdAt,
    required this.isFriend,
    required this.likesCount,
    required this.commentsCount,
    required this.comments,
    this.likedByMe = false,
    this.attachment,
  });

  final String id;
  final int authorUserId;
  final String author;
  final String text;
  final DateTime createdAt;
  final bool isFriend;
  final int likesCount;
  final int commentsCount;
  final List<_ThoughtComment> comments;
  final bool likedByMe;
  final _ThoughtAttachment? attachment;

  _ThoughtItem copyWith({
    String? text,
    int? likesCount,
    int? commentsCount,
    List<_ThoughtComment>? comments,
    bool? likedByMe,
  }) {
    return _ThoughtItem(
      id: id,
      authorUserId: authorUserId,
      author: author,
      text: text ?? this.text,
      createdAt: createdAt,
      isFriend: isFriend,
      attachment: attachment,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      comments: comments ?? this.comments,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

class _ThoughtComment {
  const _ThoughtComment({
    required this.id,
    required this.authorUserId,
    required this.author,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final int authorUserId;
  final String author;
  final String text;
  final DateTime createdAt;
}

class _CommentEditSheet extends StatefulWidget {
  const _CommentEditSheet({required this.initialText});

  final String initialText;

  @override
  State<_CommentEditSheet> createState() => _CommentEditSheetState();
}

class _CommentEditSheetState extends State<_CommentEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: palette.cardBackground.withValues(alpha: 0.92),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.t('thoughts.edit'),
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: context.t('thoughts.addComment'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t('common.cancel')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final text = _controller.text.trim();
                          if (text.isEmpty) return;
                          Navigator.of(context).pop(text);
                        },
                        child: Text(context.t('common.save')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
    this.serverTrackId,
  });

  final _ThoughtAttachmentType type;
  final String title;
  final String? subtitle;
  final String? trackAssetPath;
  final String? playlistId;
  final int? serverTrackId;
}
