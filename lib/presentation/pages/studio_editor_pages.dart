import 'dart:async' show unawaited;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/platform/cover_pick_save.dart';
import '../../core/studio/album.dart';
import '../../core/network/albums_api.dart';
import '../../core/network/tracks_api.dart';
import '../../core/network/server_connectivity.dart';
import '../../core/network/tracks_upload_api.dart';
import '../../core/studio/audio_file_metadata_reader.dart';
import '../../core/studio/studio_constants.dart';
import '../../core/studio/studio_repository.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_snack_bar.dart';
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
  bool _parsingMetadata = false;
  bool _serverUploading = false;
  /// true только если пользователь сам выбрал/заменил обложку (не из тегов файла).
  bool _userChoseCustomCover = false;
  int _wizardStep = 0;
  int? _serverTrackId;
  String _lastUploadedAudioPath = '';
  Uint8List? _serverCoverPreviewBytes;

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

  Future<void> _pickAudioFile() async {
    final copied = await pickAndSaveTrackAudio(widget.assetPath);
    if (copied == null || !mounted) return;
    setState(() {
      _audioPath = copied;
      _userChoseCustomCover = false;
      _clearServerDraft();
    });
    await _parseMetadataFromAudio(copied);
  }

  Future<void> _parseMetadataFromAudio(String path) async {
    setState(() => _parsingMetadata = true);
    ParsedAudioFileMetadata parsed;
    try {
      parsed = await AudioFileMetadataReader.instance.read(
        audioFilePath: path,
        studioAssetId: widget.assetPath,
      );
    } catch (_) {
      parsed = const ParsedAudioFileMetadata();
    }
    if (!mounted) return;
    _applyParsedMetadata(parsed);
    setState(() => _parsingMetadata = false);
  }

  void _applyParsedMetadata(ParsedAudioFileMetadata parsed) {
    final nick = widget.nickname ?? '';
    final fillTitle = _titleCtrl.text.trim().isEmpty;
    final fillArtist = _artistCtrl.text.trim().isEmpty;

    if (fillTitle && parsed.title != null) {
      _titleCtrl.text = parsed.title!;
    }
    if (fillArtist && parsed.primaryArtist != null) {
      _artistCtrl.text = parsed.primaryArtist!;
      _authorIsMe = nick.isNotEmpty && _artistCtrl.text.trim() == nick;
    }
    if (parsed.coAuthors.isNotEmpty && _coAuthors.isEmpty) {
      _coAuthors = List<String>.from(parsed.coAuthors);
    }
    if (_coverPath.isEmpty && parsed.coverPath != null && parsed.coverPath!.isNotEmpty) {
      _coverPath = parsed.coverPath!;
    }

    setState(() {});

    if (!mounted) return;
    final msg = parsed.hadEmbeddedTags
        ? context.t('studio.upload.metadataApplied')
        : parsed.usedFilenameFallback && parsed.hasSuggestions
            ? context.t('studio.upload.metadataPartial')
            : parsed.hasSuggestions
                ? context.t('studio.upload.metadataPartial')
                : context.t('studio.upload.metadataNone');
    showGlassSnackBar(context, msg);

    if (_serverLoggedIn && _audioPath.isNotEmpty) {
      unawaited(_syncTrackToServer(showSnack: false));
    }
  }

  bool get _shouldUploadCustomCover =>
      _userChoseCustomCover && _coverPath.isNotEmpty && !kIsWeb;

  void _showUploadErrorSnack(Object error, {String? prefix}) {
    if (!mounted) return;
    final detail = tracksUploadErrorDetail(error);
    final base = prefix ?? context.t('studio.serverUploadFail');
    final msg = detail.isEmpty || detail == error.toString()
        ? base
        : '$base: $detail';
    showGlassSnackBar(context, msg);
    if (error is DioException) {
      unawaited(ServerConnectivity.instance.reportNetworkErrorIfOffline(context, error));
    }
  }

  Future<bool> _audioFileReady() async {
    if (_audioPath.isEmpty) return false;
    if (kIsWeb) return true;
    return File(_audioPath).existsSync();
  }

  Future<void> _onWizardNext() async {
    if (_wizardStep == 0) {
      if (!await _audioFileReady()) {
        if (!mounted) return;
        showGlassSnackBar(context, context.t('studio.upload.needAudioForNext'));
        return;
      }
      setState(() => _wizardStep = 1);
      return;
    }
    if (_wizardStep == 1) {
      if (_serverLoggedIn) {
        if (_serverTrackId == null) {
          await _syncTrackToServer(showSnack: true);
        } else {
          await _updateServerMetadataQuiet();
        }
      }
      if (!mounted) return;
      setState(() => _wizardStep = 2);
    }
  }

  Future<void> _updateServerMetadataQuiet() async {
    final id = _serverTrackId;
    if (id == null || !_serverLoggedIn) return;
    final title = _titleCtrl.text.trim();
    final artist = _artistCtrl.text.trim();
    try {
      await TracksApi().updateTrackMetadata(
        trackId: id,
        title: title.isEmpty ? null : title,
        artist: artist.isEmpty ? null : artist,
      );
    } catch (_) {}
  }

  Future<bool> _syncTrackToServer({bool showSnack = true}) async {
    if (!_serverLoggedIn) {
      if (showSnack && mounted) {
        showGlassSnackBar(context, context.t('studio.serverNeedLogin'));
      }
      return false;
    }
    if (!await _audioFileReady()) {
      if (showSnack && mounted) {
        showGlassSnackBar(context, context.t('studio.upload.needAudioForNext'));
      }
      return false;
    }
    if (_serverUploading) return _serverTrackId != null;
    setState(() => _serverUploading = true);
    final api = TracksUploadApi();
    var id = _serverTrackId;
    var coverWarning = false;
    try {
      final mustUploadAudio = id == null || _lastUploadedAudioPath != _audioPath;
      if (mustUploadAudio) {
        File? coverForUpload;
        if (_shouldUploadCustomCover) {
          final coverFile = File(_coverPath);
          if (await coverFile.exists()) coverForUpload = coverFile;
        }
        try {
          final result = await api.uploadTrack(
            audioFile: File(_audioPath),
            title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
            artist: _artistCtrl.text.trim().isEmpty ? null : _artistCtrl.text.trim(),
            coverFile: coverForUpload,
            genreSlugs: const [],
          );
          id = result.trackId;
          if (!mounted) return true;
          setState(() {
            _serverTrackId = id;
            _lastUploadedAudioPath = _audioPath;
          });
          final serverHasCover = result.embeddedCoverApplied ||
              result.customCoverApplied ||
              (result.coverStorageKey != null && result.coverStorageKey!.isNotEmpty);
          if (!serverHasCover &&
              !_userChoseCustomCover &&
              _coverPath.isNotEmpty &&
              !kIsWeb) {
            try {
              final embeddedFile = File(_coverPath);
              if (await embeddedFile.exists()) {
                await api.uploadTrackCover(trackId: id, imageFile: embeddedFile);
              }
            } catch (e, st) {
              debugPrint('Studio embedded cover fallback upload: $e\n$st');
              coverWarning = true;
            }
          }
        } catch (e, st) {
          debugPrint('Studio upload audio failed: $e\n$st');
          if (showSnack && mounted) _showUploadErrorSnack(e);
          return false;
        }
      } else {
        await _updateServerMetadataQuiet();
      }

      try {
        await api.putTrackGenres(trackId: id, genreSlugs: _genres, normalizeWeights: false);
      } catch (e, st) {
        debugPrint('Studio upload genres failed: $e\n$st');
        coverWarning = true;
      }

      if (_shouldUploadCustomCover) {
        try {
          final coverFile = File(_coverPath);
          if (await coverFile.exists()) {
            await api.uploadTrackCover(trackId: id, imageFile: coverFile);
          }
        } catch (e, st) {
          debugPrint('Studio upload cover failed: $e\n$st');
          coverWarning = true;
        }
      }

      final bytes = await TracksUploadApi.fetchTrackCoverBytes(id);
      if (mounted && bytes != null && bytes.isNotEmpty) {
        setState(() => _serverCoverPreviewBytes = bytes);
      }
      if (showSnack && mounted) {
        if (coverWarning) {
          showGlassSnackBar(context, context.t('studio.upload.partialOk'));
        } else {
          showGlassSnackBar(context, context.t('studio.serverUploadOk'));
        }
      }
      return true;
    } finally {
      if (mounted) setState(() => _serverUploading = false);
    }
  }

  Future<void> _publishTrackToServer() async {
    await _syncTrackToServer(showSnack: true);
  }

  void _addCoAuthorFromField() {
    final name = _coAuthorCtrl.text.trim();
    if (name.isNotEmpty && !_coAuthors.contains(name)) {
      setState(() => _coAuthors.add(name));
      _coAuthorCtrl.clear();
    }
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final artist = _artistCtrl.text.trim();
    if (_serverLoggedIn && await _audioFileReady()) {
      final ok = await _syncTrackToServer(showSnack: false);
      if (!ok) {
        if (!mounted) return;
        showGlassSnackBar(context, context.t('studio.serverUploadFail'));
        return;
      }
    } else if (_serverTrackId != null && _serverLoggedIn) {
      try {
        await TracksApi().updateTrackMetadata(
          trackId: _serverTrackId!,
          title: title.isEmpty ? null : title,
          artist: artist.isEmpty ? null : artist,
        );
      } catch (_) {
        if (!mounted) return;
        showGlassSnackBar(context, context.t('studio.serverUploadFail'));
        return;
      }
    }
    if (!mounted) return;
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
              if (_serverLoggedIn && _audioPath.isNotEmpty)
                IconButton(
                  tooltip: context.t('studio.publishToServer'),
                  onPressed: (_parsingMetadata || _serverUploading) ? null : () => unawaited(_publishTrackToServer()),
                  icon: _serverUploading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent),
                        )
                      : Icon(
                          _serverTrackId != null ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
                        ),
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
                            ? context.t('studio.upload.stepAudio')
                            : _wizardStep == 1
                                ? context.t('studio.upload.stepMeta')
                                : context.t('studio.upload.stepCover'),
                        style: TextStyle(fontSize: 12, color: palette.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  children: [
                    if (_wizardStep == 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: studioGlassPanel(
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
                      ),
                    if (_wizardStep == 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: studioGlassPanel(
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _parsingMetadata ? null : () => unawaited(_pickAudioFile()),
                                  icon: _parsingMetadata
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: palette.accent,
                                          ),
                                        )
                                      : const Icon(Icons.upload_file_rounded, size: 20),
                                  label: Text(
                                    _parsingMetadata
                                        ? context.t('studio.upload.parsingMetadata')
                                        : context.t('playlists.chooseFile'),
                                  ),
                                ),
                              ],
                            ),
                            if (_parsingMetadata) ...[
                              const SizedBox(height: 8),
                              Text(
                                context.t('studio.upload.parsingMetadata'),
                                style: TextStyle(fontSize: 12, color: palette.textSecondary),
                              ),
                            ],
                            if (_audioPath.isNotEmpty &&
                                (_titleCtrl.text.trim().isNotEmpty ||
                                    _artistCtrl.text.trim().isNotEmpty)) ...[
                              const SizedBox(height: 12),
                              Text(
                                context.t('studio.upload.metadataApplied'),
                                style: TextStyle(fontSize: 12, color: palette.accent, height: 1.35),
                              ),
                              if (_titleCtrl.text.trim().isNotEmpty)
                                Text(
                                  '${context.t('playlists.name')}: ${_titleCtrl.text.trim()}',
                                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                                ),
                              if (_artistCtrl.text.trim().isNotEmpty)
                                Text(
                                  '${context.t('studio.artist')}: ${_artistCtrl.text.trim()}',
                                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                                ),
                            ],
                          ],
                        ),
                      ),
                      ),
                      if (_coverPath.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            context.t('studio.upload.embeddedCoverHint'),
                            style: TextStyle(fontSize: 12, color: palette.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        studioGlassSquareCover(
                          context: context,
                          palette: palette,
                          coverPath: _coverPath,
                        ),
                      ],
                    ],
                    if (_wizardStep == 2) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: studioGlassPanel(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_serverUploading) ...[
                              Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: palette.accent),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      context.t('studio.upload.uploading'),
                                      style: TextStyle(fontSize: 12, color: palette.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ] else if (_serverTrackId != null) ...[
                              Row(
                                children: [
                                  Icon(Icons.cloud_done_rounded, size: 16, color: palette.accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.t('studio.onServer'),
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.accent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.t('studio.upload.finalizeHint'),
                                style: TextStyle(fontSize: 12, color: palette.textSecondary, height: 1.35),
                              ),
                              const SizedBox(height: 12),
                            ] else if (_serverLoggedIn)
                              Text(
                                context.t('studio.upload.offlineStep3'),
                                style: TextStyle(fontSize: 12, color: palette.textSecondary, height: 1.35),
                              )
                            else
                              Text(
                                context.t('studio.upload.loginForServer'),
                                style: TextStyle(fontSize: 12, color: palette.textSecondary, height: 1.35),
                              ),
                            if (_serverLoggedIn && !_serverUploading)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: _parsingMetadata ? null : () => unawaited(_publishTrackToServer()),
                                  icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                                  label: Text(context.t('studio.publishToServer')),
                                ),
                              ),
                            if (_serverLoggedIn && !_serverUploading) const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () async {
                                final copied = await pickAndSaveCoverImage(widget.assetPath);
                                if (copied != null && mounted) {
                                  setState(() {
                                    _coverPath = copied;
                                    _userChoseCustomCover = true;
                                  });
                                }
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
                      ),
                      if (_coverPath.isNotEmpty ||
                          (_serverCoverPreviewBytes != null && _serverCoverPreviewBytes!.isNotEmpty)) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _serverTrackId != null
                                ? context.t('studio.upload.coverFromServer')
                                : context.t('studio.upload.embeddedCoverHint'),
                            style: TextStyle(fontSize: 12, color: palette.textSecondary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        studioGlassSquareCover(
                          context: context,
                          palette: palette,
                          coverPath: _coverPath.isNotEmpty ? _coverPath : null,
                          coverBytes: (_coverPath.isEmpty &&
                                  _serverCoverPreviewBytes != null &&
                                  _serverCoverPreviewBytes!.isNotEmpty)
                              ? _serverCoverPreviewBytes
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ] else if (_serverTrackId != null) ...[
                        const SizedBox(height: 12),
                        studioGlassSquareCover(
                          context: context,
                          palette: palette,
                          emptyPlaceholder: Container(
                            decoration: BoxDecoration(
                              color: palette.primaryDark.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              context.t('studio.upload.noCoverPreview'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: palette.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
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
                          onPressed: () {
                                  if (_wizardStep == 2) {
                                    setState(() => _wizardStep = 1);
                                  } else if (_wizardStep == 1) {
                                    setState(() => _wizardStep = 0);
                                  }
                                },
                          child: Text(context.t('studio.upload.back')),
                        ),
                      const Spacer(),
                      if (_wizardStep < 2)
                        FilledButton(
                          onPressed: (_parsingMetadata || _serverUploading) ? null : () => unawaited(_onWizardNext()),
                          child: Text(context.t('studio.upload.next')),
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
