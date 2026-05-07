import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/platform/cover_pick_save.dart';
import '../../core/studio/album.dart';
import '../../core/network/albums_api.dart';
import '../../core/network/tracks_upload_api.dart';
import '../../core/studio/studio_constants.dart';
import '../../core/studio/studio_repository.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/studio_genre_picker.dart';
import 'studio_ui_helpers.dart';

/// Выбор треков для альбома — отдельный диалог на корневом навигаторе (поверх [MainShell]).
Future<List<String>?> showStudioTrackIdsPickerDialog(
  BuildContext context, {
  required List<Track> allTracks,
  required List<String> currentIds,
}) {
  return showDialog<List<String>>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      var selected = List<String>.from(currentIds);
      return StatefulBuilder(
        builder: (context, setPickerState) => AlertDialog(
          title: Text(context.t('playlists.addTracks')),
          content: SizedBox(
            width: double.maxFinite,
            child: allTracks.isEmpty
                ? Text(context.t('studio.noTracksForAlbum'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: allTracks.length,
                    itemBuilder: (context, i) {
                      final track = allTracks[i];
                      final added = selected.contains(track.assetPath);
                      return CheckboxListTile(
                        title: Text(track.title, style: const TextStyle(fontSize: 13)),
                        subtitle: track.artist != null
                            ? Text(track.artist!, style: const TextStyle(fontSize: 12))
                            : null,
                        value: added,
                        onChanged: (v) {
                          if (v == true) {
                            selected.add(track.assetPath);
                          } else {
                            selected.remove(track.assetPath);
                          }
                          setPickerState(() {});
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: Text(context.t('common.done'))),
          ],
        ),
      );
    },
  );
}

/// Редактор альбома поверх всего приложения (корневой [Navigator]).
class StudioAlbumEditorPage extends StatefulWidget {
  const StudioAlbumEditorPage({
    super.key,
    required this.initialAlbum,
    required this.allTracks,
    required this.suggestArtists,
  });

  final Album? initialAlbum;
  final List<Track> allTracks;
  final List<String> Function(String query) suggestArtists;

  @override
  State<StudioAlbumEditorPage> createState() => _StudioAlbumEditorPageState();
}

class _StudioAlbumEditorPageState extends State<StudioAlbumEditorPage> {
  late final String _albumId;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late String _coverPath;
  late List<String> _trackIds;
  late List<String> _genres;
  bool _serverLoggedIn = false;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAlbum;
    _albumId = a?.id ?? 'album_${DateTime.now().millisecondsSinceEpoch}';
    _titleCtrl = TextEditingController(text: a?.title ?? '');
    _artistCtrl = TextEditingController(text: a?.artist ?? '');
    _coverPath = a?.coverPath ?? '';
    _trackIds = List<String>.from(a?.trackAssetPaths ?? []);
    _genres = normalizeStudioGenreList(a?.genres ?? []);
    AuthSessionStore.readAccount().then((acc) {
      if (!mounted) return;
      setState(() {
        _serverLoggedIn =
            acc != null && acc.sessionToken.isNotEmpty && acc.userId != null;
      });
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    super.dispose();
  }

  Future<void> _publishAlbumToServer() async {
    if (!_serverLoggedIn) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.t('studio.serverNeedLogin'))),
      );
      return;
    }
    final title = _titleCtrl.text.trim();
    final resolvedTitle = title.isEmpty ? context.t('playlists.untitled') : title;
    try {
      await AlbumsApi().createAlbum(
        title: resolvedTitle,
        genreSlugs: _genres,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('studio.serverAlbumOk'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('studio.serverAlbumFail'))),
      );
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final artist = _artistCtrl.text.trim();
    Navigator.pop(
      context,
      Album(
        id: _albumId,
        title: title.isEmpty ? context.t('playlists.untitled') : title,
        artist: artist.isEmpty ? null : artist,
        coverPath: _coverPath.isEmpty ? null : _coverPath,
        trackAssetPaths: _trackIds,
        genres: List<String>.from(_genres),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final suggestions = widget.suggestArtists(_artistCtrl.text);

    return PopScope(
      canPop: true,
      child: Container(
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
            elevation: 0,
            iconTheme: IconThemeData(color: palette.textPrimary),
            title: Text(
              widget.initialAlbum == null ? context.t('studio.newAlbum') : context.t('studio.editAlbum'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            actions: [
              if (_serverLoggedIn)
                IconButton(
                  tooltip: context.t('studio.publishAlbumServer'),
                  onPressed: _publishAlbumToServer,
                  icon: const Icon(Icons.cloud_upload_rounded),
                ),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
              FilledButton(onPressed: _submit, child: Text(context.t('common.save'))),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: studioGlassFieldDecoration(
                  palette: palette,
                  labelText: context.t('playlists.name'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _artistCtrl,
                decoration: studioGlassFieldDecoration(
                  palette: palette,
                  labelText: context.t('studio.artist'),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: palette.primaryDark.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    border: Border.all(color: palette.textPrimary.withValues(alpha: 0.08)),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: suggestions.length,
                    itemBuilder: (context, i) {
                      final suggestion = suggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text(suggestion, style: TextStyle(color: palette.textPrimary)),
                        onTap: () {
                          _artistCtrl.text = suggestion;
                          _artistCtrl.selection = TextSelection.collapsed(offset: suggestion.length);
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(context.t('playlists.cover'), style: TextStyle(fontSize: 12, color: palette.textSecondary)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  studioDialogCoverPreview(palette, _coverPath, 72),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final copied = await pickAndSaveCoverImage(_albumId);
                        if (copied != null && mounted) setState(() => _coverPath = copied);
                      },
                      icon: const Icon(Icons.image_rounded, size: 20),
                      label: Text(
                        _coverPath.isEmpty ? context.t('playlists.chooseFile') : context.t('playlists.replace'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(context.t('studio.genres'), style: TextStyle(fontSize: 12, color: palette.textSecondary)),
              const SizedBox(height: 6),
              StudioGenrePicker(
                palette: palette,
                selected: _genres,
                onSelectionChanged: (v) => setState(() => _genres = v),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.t('studio.tracksInAlbum'),
                    style: TextStyle(fontSize: 14, color: palette.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: widget.allTracks.isEmpty
                        ? null
                        : () async {
                            final picked = await showStudioTrackIdsPickerDialog(
                              context,
                              allTracks: widget.allTracks,
                              currentIds: _trackIds,
                            );
                            if (picked != null) setState(() => _trackIds = picked);
                          },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(context.t('studio.add')),
                  ),
                ],
              ),
              ..._trackIds.map((trackId) {
                Track? t;
                for (final x in widget.allTracks) {
                  if (x.assetPath == trackId) {
                    t = x;
                    break;
                  }
                }
                return ListTile(
                  title: Text(t?.title ?? trackId, style: const TextStyle(fontSize: 13)),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () => setState(() => _trackIds = _trackIds.where((p) => p != trackId).toList()),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Редактор метаданных трека на корневом навигаторе.
class StudioTrackEditorPage extends StatefulWidget {
  const StudioTrackEditorPage({
    super.key,
    required this.assetPath,
    required this.track,
    required this.metadataOverride,
    required this.nickname,
    required this.suggestArtists,
  });

  final String assetPath;
  final Track? track;
  final TrackMetadataOverride? metadataOverride;
  final String? nickname;
  final List<String> Function(String query) suggestArtists;

  @override
  State<StudioTrackEditorPage> createState() => _StudioTrackEditorPageState();
}

class _StudioTrackEditorPageState extends State<StudioTrackEditorPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _coAuthorCtrl;
  late String _coverPath;
  late String _audioPath;
  late List<String> _genres;
  late List<String> _coAuthors;
  late bool _authorIsMe;
  bool _serverLoggedIn = false;
  int _wizardStep = 0;
  int? _serverTrackId;
  String _lastUploadedAudioPath = '';
  Uint8List? _serverCoverPreviewBytes;
  bool _step2Uploading = false;

  void _clearServerDraft() {
    _serverTrackId = null;
    _lastUploadedAudioPath = '';
    _serverCoverPreviewBytes = null;
  }

  @override
  void initState() {
    super.initState();
    final tr = widget.track;
    final o = widget.metadataOverride;
    _titleCtrl = TextEditingController(text: tr?.title ?? '');
    _artistCtrl = TextEditingController(text: o?.artist ?? '');
    _coverPath = o?.coverPath ?? '';
    _audioPath = o?.audioFilePath ?? '';
    _genres = normalizeStudioGenreList(o?.genres ?? []);
    _coAuthors = List<String>.from(o?.coAuthors ?? []);
    final nick = widget.nickname ?? '';
    _authorIsMe = nick.isNotEmpty && _artistCtrl.text.trim() == nick;
    _coAuthorCtrl = TextEditingController();
    _serverTrackId = o?.serverTrackId;
    if (_serverTrackId != null && _audioPath.isNotEmpty) {
      _lastUploadedAudioPath = _audioPath;
    }
    AuthSessionStore.readAccount().then((acc) {
      if (!mounted) return;
      setState(() {
        _serverLoggedIn =
            acc != null && acc.sessionToken.isNotEmpty && acc.userId != null;
      });
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _coAuthorCtrl.dispose();
    super.dispose();
  }

  Future<void> _onWizardNext() async {
    if (_wizardStep == 0) {
      setState(() => _wizardStep = 1);
      return;
    }
    if (_wizardStep == 1) {
      if (_audioPath.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('studio.upload.needAudioForNext'))),
        );
        return;
      }
      final f = File(_audioPath);
      if (!f.existsSync()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('studio.upload.needAudioForNext'))),
        );
        return;
      }
      if (!_serverLoggedIn) {
        setState(() {
          _clearServerDraft();
          _wizardStep = 2;
        });
        return;
      }
      if (_serverTrackId != null && _lastUploadedAudioPath == _audioPath) {
        setState(() => _wizardStep = 2);
        return;
      }
      setState(() => _step2Uploading = true);
      try {
        final file = File(_audioPath);
        final result = await TracksUploadApi().uploadTrack(
          audioFile: file,
          title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
          artist: _artistCtrl.text.trim().isEmpty ? null : _artistCtrl.text.trim(),
          coverFile: null,
          genreSlugs: const [],
        );
        final preview = await TracksUploadApi.fetchTrackCoverBytes(result.trackId);
        if (!mounted) return;
        setState(() {
          _step2Uploading = false;
          _serverTrackId = result.trackId;
          _lastUploadedAudioPath = _audioPath;
          _serverCoverPreviewBytes = preview;
          _wizardStep = 2;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _step2Uploading = false);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('studio.upload.audioUploadFail'))),
        );
      }
      return;
    }
  }

  Future<void> _publishTrackToServer() async {
    if (!_serverLoggedIn) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.t('studio.serverNeedLogin'))),
      );
      return;
    }
    final id = _serverTrackId;
    if (id == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.t('studio.upload.loginForServer'))),
      );
      return;
    }
    try {
      final api = TracksUploadApi();
      await api.putTrackGenres(trackId: id, genreSlugs: _genres, normalizeWeights: false);
      if (_coverPath.isNotEmpty) {
        final coverFile = File(_coverPath);
        if (await coverFile.exists()) {
          await api.uploadTrackCover(trackId: id, imageFile: coverFile);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('studio.serverUploadOk'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('studio.serverUploadFail'))),
      );
    }
  }

  void _addCoAuthorFromField() {
    final name = _coAuthorCtrl.text.trim();
    if (name.isNotEmpty && !_coAuthors.contains(name)) {
      setState(() => _coAuthors.add(name));
      _coAuthorCtrl.clear();
    }
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    final artist = _artistCtrl.text.trim();
    Navigator.pop(
      context,
      (
        assetPath: widget.assetPath,
        metadata: TrackMetadataOverride(
          title: title.isEmpty ? null : title,
          artist: artist.isEmpty ? null : artist,
          coverPath: _coverPath.isEmpty ? null : _coverPath,
          genres: List<String>.from(_genres),
          audioFilePath: _audioPath.isEmpty ? null : _audioPath,
          coAuthors: List<String>.from(_coAuthors),
          serverTrackId: _serverTrackId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final nick = widget.nickname ?? '';
    final artistSuggestions = !_authorIsMe ? widget.suggestArtists(_artistCtrl.text) : const <String>[];
    final coRaw = widget.suggestArtists(_coAuthorCtrl.text);
    final coSuggestions = coRaw.where((s) => !_coAuthors.contains(s)).take(8).toList();

    return PopScope(
      canPop: true,
      child: Container(
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
            elevation: 0,
            iconTheme: IconThemeData(color: palette.textPrimary),
            title: Text(
              widget.track == null ? context.t('studio.newTrack') : context.t('studio.editTrack'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            actions: [
              if (_serverLoggedIn && _wizardStep == 2 && _serverTrackId != null)
                IconButton(
                  tooltip: context.t('studio.publishToServer'),
                  onPressed: _publishTrackToServer,
                  icon: const Icon(Icons.cloud_upload_rounded),
                ),
              TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t('common.cancel'))),
              FilledButton(onPressed: _submit, child: Text(context.t('common.save'))),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: studioGlassPanel(
                  context: context,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: List.generate(3, (i) {
                          final active = i <= _wizardStep;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: active ? palette.accent : palette.textMuted.withValues(alpha: 0.28),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _wizardStep == 0
                            ? context.t('studio.upload.stepMeta')
                            : _wizardStep == 1
                                ? context.t('studio.upload.stepAudio')
                                : context.t('studio.upload.stepCover'),
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  children: [
                    if (_wizardStep == 0)
                      studioGlassPanel(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _titleCtrl,
                              decoration: studioGlassFieldDecoration(
                                palette: palette,
                                labelText: context.t('playlists.name'),
                              ),
                            ),
                      const SizedBox(height: 16),
                      if (nick.isNotEmpty)
                        CheckboxListTile(
                          value: _authorIsMe,
                          onChanged: (v) => setState(() {
                            _authorIsMe = v ?? false;
                            if (_authorIsMe) {
                              _artistCtrl.text = nick;
                              _artistCtrl.selection = TextSelection.collapsed(offset: nick.length);
                            }
                          }),
                          title: Text(context.t('studio.iAmAuthor')),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      TextField(
                        controller: _artistCtrl,
                        readOnly: _authorIsMe,
                        decoration: studioGlassFieldDecoration(
                          palette: palette,
                          labelText: context.t('studio.artist'),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (!_authorIsMe && artistSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 160),
                          decoration: BoxDecoration(
                            color: palette.primaryDark.withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                            border: Border.all(color: palette.textPrimary.withValues(alpha: 0.08)),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: artistSuggestions.length,
                            itemBuilder: (context, i) {
                              final suggestion = artistSuggestions[i];
                              return ListTile(
                                dense: true,
                                title: Text(suggestion, style: TextStyle(color: palette.textPrimary)),
                                onTap: () {
                                  _artistCtrl.text = suggestion;
                                  _artistCtrl.selection = TextSelection.collapsed(offset: suggestion.length);
                                  setState(() {});
                                },
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(context.t('studio.coAuthors'), style: TextStyle(fontSize: 12, color: palette.textSecondary)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _coAuthors
                            .map(
                              (name) => Chip(
                                label: Text(name),
                                onDeleted: () => setState(() => _coAuthors.remove(name)),
                                deleteIconColor: palette.textMuted,
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _coAuthorCtrl,
                                  decoration: studioGlassFieldDecoration(
                                    palette: palette,
                                    labelText: context.t('studio.coAuthorName'),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  onSubmitted: (_) => _addCoAuthorFromField(),
                                ),
                                if (coSuggestions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    constraints: const BoxConstraints(maxHeight: 120),
                                    decoration: BoxDecoration(
                                      color: palette.primaryDark.withValues(alpha: 0.24),
                                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                      border: Border.all(color: palette.textPrimary.withValues(alpha: 0.08)),
                                    ),
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: coSuggestions.length,
                                      itemBuilder: (context, i) {
                                        final suggestion = coSuggestions[i];
                                        return ListTile(
                                          dense: true,
                                          title: Text(suggestion, style: TextStyle(color: palette.textPrimary)),
                                          onTap: () {
                                            if (!_coAuthors.contains(suggestion)) {
                                              setState(() => _coAuthors.add(suggestion));
                                              _coAuthorCtrl.clear();
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: FilledButton(
                              onPressed: _addCoAuthorFromField,
                              child: Text(context.t('studio.add')),
                            ),
                          ),
                        ],
                      ),
                          ],
                        ),
                      ),
                    if (_wizardStep == 1)
                      studioGlassPanel(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.t('studio.audioFile'),
                              style: TextStyle(fontSize: 12, color: palette.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _audioPath.isEmpty
                                        ? context.t('studio.notSelected')
                                        : _audioPath.split(RegExp(r'[/\\]')).last,
                                    style: TextStyle(fontSize: 13, color: palette.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _step2Uploading
                                      ? null
                                      : () async {
                                          final copied = await pickAndSaveTrackAudio(widget.assetPath);
                                          if (copied != null && mounted) setState(() => _audioPath = copied);
                                        },
                                  icon: const Icon(Icons.upload_file_rounded, size: 20),
                                  label: Text(context.t('playlists.chooseFile')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (_wizardStep == 2)
                      studioGlassPanel(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_serverTrackId == null)
                              Text(
                                context.t('studio.upload.offlineStep3'),
                                style: TextStyle(fontSize: 12, color: palette.textSecondary, height: 1.35),
                              )
                            else
                              ...[
                              Text(
                                context.t('studio.upload.finalizeHint'),
                                style: TextStyle(fontSize: 12, color: palette.textSecondary, height: 1.35),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                context.t('studio.upload.coverFromServer'),
                                style: TextStyle(fontSize: 12, color: palette.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                child: SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: _coverPath.isNotEmpty
                                      ? studioDialogCoverPreview(palette, _coverPath, 120)
                                      : (_serverCoverPreviewBytes != null &&
                                              _serverCoverPreviewBytes!.isNotEmpty)
                                          ? Image.memory(
                                              _serverCoverPreviewBytes!,
                                              fit: BoxFit.cover,
                                              gaplessPlayback: true,
                                            )
                                          : Container(
                                              color: palette.primaryDark.withValues(alpha: 0.35),
                                              alignment: Alignment.center,
                                              padding: const EdgeInsets.all(8),
                                              child: Text(
                                                context.t('studio.upload.noCoverPreview'),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(fontSize: 11, color: palette.textMuted),
                                              ),
                                            ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextButton.icon(
                              onPressed: () async {
                                final copied = await pickAndSaveCoverImage(widget.assetPath);
                                if (copied != null && mounted) setState(() => _coverPath = copied);
                              },
                              icon: const Icon(Icons.image_rounded, size: 20),
                              label: Text(
                                _coverPath.isEmpty ? context.t('playlists.chooseFile') : context.t('playlists.replace'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.t('studio.genres'),
                              style: TextStyle(fontSize: 12, color: palette.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            StudioGenrePicker(
                              palette: palette,
                              selected: _genres,
                              onSelectionChanged: (v) => setState(() => _genres = v),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: studioGlassPanel(
                  context: context,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      if (_wizardStep > 0)
                        TextButton(
                          onPressed: _step2Uploading
                              ? null
                              : () {
                                  if (_wizardStep == 2) {
                                    setState(() => _wizardStep = 1);
                                  } else if (_wizardStep == 1) {
                                    setState(() {
                                      _clearServerDraft();
                                      _wizardStep = 0;
                                    });
                                  }
                                },
                          child: Text(context.t('studio.upload.back')),
                        ),
                      const Spacer(),
                      if (_wizardStep < 2)
                        FilledButton(
                          onPressed: _step2Uploading ? null : () => unawaited(_onWizardNext()),
                          child: _step2Uploading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.textPrimary,
                                  ),
                                )
                              : Text(context.t('studio.upload.next')),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
