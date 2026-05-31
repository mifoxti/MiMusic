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
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_snack_bar.dart';
import '../widgets/studio_genre_picker.dart';
import 'studio_ui_helpers.dart';

/// Р’С‹Р±РѕСЂ С‚СЂРµРєРѕРІ РґР»СЏ Р°Р»СЊР±РѕРјР° вЂ” РѕС‚РґРµР»СЊРЅС‹Р№ РґРёР°Р»РѕРі РЅР° РєРѕСЂРЅРµРІРѕРј РЅР°РІРёРіР°С‚РѕСЂРµ (РїРѕРІРµСЂС… [MainShell]).
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

/// Р РµРґР°РєС‚РѕСЂ Р°Р»СЊР±РѕРјР° РїРѕРІРµСЂС… РІСЃРµРіРѕ РїСЂРёР»РѕР¶РµРЅРёСЏ (РєРѕСЂРЅРµРІРѕР№ [Navigator]).
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

/// Р РµРґР°РєС‚РѕСЂ РјРµС‚Р°РґР°РЅРЅС‹С… С‚СЂРµРєР° РЅР° РєРѕСЂРЅРµРІРѕРј РЅР°РІРёРіР°С‚РѕСЂРµ.
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
  /// true С‚РѕР»СЊРєРѕ РµСЃР»Рё РїРѕР»СЊР·РѕРІР°С‚РµР»СЊ СЃР°Рј РІС‹Р±СЂР°Р»/Р·Р°РјРµРЅРёР» РѕР±Р»РѕР¶РєСѓ (РЅРµ РёР· С‚РµРіРѕРІ С„Р°Р№Р»Р°).
  bool _userChoseCustomCover = false;
  int? _serverTrackId;
  String _lastUploadedAudioPath = '';
  Uint8List? _serverCoverPreviewBytes;
  bool _baselineReady = false;
  late String _baselineTitle;
  late String _baselineArtist;
  late List<String> _baselineCoAuthors;
  late List<String> _baselineGenres;
  late String _baselineCoverPath;
  bool _baselineCoverCustom = false;
  int _baselineCoverBytesLength = 0;

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
    _titleCtrl = TextEditingController(text: tr?.title ?? o?.title ?? '');
    _artistCtrl = TextEditingController(text: (o?.artist ?? tr?.artist ?? '').trim());
    _coverPath = o?.coverPath ?? '';
    _audioPath = o?.audioFilePath ?? tr?.audioFilePath ?? '';
    if (tr?.coverBytes != null && tr!.coverBytes!.isNotEmpty) {
      _serverCoverPreviewBytes = tr.coverBytes;
    }
    _genres = normalizeStudioGenreList(o?.genres ?? []);
    _coAuthors = List<String>.from(o?.coAuthors ?? []);
    final nick = widget.nickname ?? '';
    _authorIsMe = nick.isNotEmpty && _artistCtrl.text.trim() == nick;
    _coAuthorCtrl = TextEditingController();
    _serverTrackId = TracksApi().resolveServerTrackId(
      assetPath: widget.assetPath,
      audioFilePath: _audioPath,
      metadataServerTrackId: o?.serverTrackId,
    );
    if (_serverTrackId != null && _audioPath.isNotEmpty) {
      _lastUploadedAudioPath = _audioPath;
    }
    _titleCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _artistCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    AuthSessionStore.readAccount().then((acc) {
      if (!mounted) return;
      setState(() {
        _serverLoggedIn =
            acc != null && acc.sessionToken.isNotEmpty && acc.userId != null;
      });
    });
    unawaited(_hydrateFromServerIfNeeded());
  }

  void _captureBaseline() {
    _baselineTitle = _titleCtrl.text.trim();
    _baselineArtist = _artistCtrl.text.trim();
    _baselineCoAuthors = List<String>.from(_coAuthors);
    _baselineGenres = List<String>.from(_genres);
    _baselineCoverPath = _coverPath;
    _baselineCoverCustom = _userChoseCustomCover;
    _baselineCoverBytesLength = _serverCoverPreviewBytes?.length ?? 0;
    _baselineReady = true;
  }

  Future<void> _ensureServerCoverLoaded(int trackId) async {
    if (_coverPath.isNotEmpty && !kIsWeb && File(_coverPath).existsSync()) return;
    if (_serverCoverPreviewBytes != null && _serverCoverPreviewBytes!.isNotEmpty) {
      return;
    }
    try {
      final bytes = await TracksUploadApi.fetchTrackCoverBytes(trackId);
      if (!mounted || bytes == null || bytes.isEmpty) return;
      setState(() => _serverCoverPreviewBytes = bytes);
    } catch (_) {}
  }

  Future<void> _hydrateFromServerIfNeeded() async {
    final id = _serverTrackId;
    if (id == null) {
      if (mounted) {
        setState(() {});
        _captureBaseline();
      }
      return;
    }
    unawaited(_ensureServerCoverLoaded(id));
    try {
      final item = await TracksApi().fetchTrackById(id);
      if (!mounted) return;
      final nick = widget.nickname ?? '';
      setState(() {
        if (item.title.trim().isNotEmpty) {
          _titleCtrl.text = item.title.trim();
        }
        if (item.artist != null && item.artist!.trim().isNotEmpty) {
          _artistCtrl.text = item.artist!.trim();
          _authorIsMe = nick.isNotEmpty && _artistCtrl.text.trim() == nick;
        }
        if (item.genres.isNotEmpty) {
          _genres = normalizeStudioGenreList(item.genres);
        }
        if (item.coverBytes != null && item.coverBytes!.isNotEmpty) {
          _serverCoverPreviewBytes = item.coverBytes;
        }
        _audioPath = item.streamUrl();
        _lastUploadedAudioPath = _audioPath;
      });
    } catch (_) {}
    if (!mounted) return;
    await _ensureServerCoverLoaded(id);
    if (!mounted) return;
    setState(() {});
    _captureBaseline();
  }

  bool get _isEditing => widget.track != null;

  bool get _titleChanged =>
      _baselineReady && _titleCtrl.text.trim() != _baselineTitle;

  bool get _artistChanged =>
      _baselineReady && _artistCtrl.text.trim() != _baselineArtist;

  bool get _coAuthorsChanged =>
      _baselineReady && !listEquals(_coAuthors, _baselineCoAuthors);

  bool get _genresChanged =>
      _baselineReady && !listEquals(_genres, _baselineGenres);

  bool get _coverChanged =>
      _baselineReady &&
      (_userChoseCustomCover != _baselineCoverCustom ||
          _coverPath != _baselineCoverPath ||
          (_serverCoverPreviewBytes?.length ?? 0) != _baselineCoverBytesLength);

  Future<void> _pickCoverImage() async {
    final copied = await pickAndSaveCoverImage(widget.assetPath);
    if (copied != null && mounted) {
      setState(() {
        _coverPath = copied;
        _userChoseCustomCover = true;
      });
    }
  }

  Widget _highlightWrap({
    required AppColorPalette palette,
    required bool changed,
    required Widget child,
  }) {
    if (!changed) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(color: palette.accent.withValues(alpha: 0.75), width: 1.5),
        color: palette.accent.withValues(alpha: 0.07),
      ),
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }

  Widget _buildCoverThumb(AppColorPalette palette, {double size = 96}) {
    final radius = BorderRadius.circular(AppConstants.radiusMedium);
    Widget image;
    if (_coverPath.isNotEmpty && !kIsWeb && File(_coverPath).existsSync()) {
      image = ClipRRect(
        borderRadius: radius,
        child: Image.file(File(_coverPath), width: size, height: size, fit: BoxFit.cover),
      );
    } else if (_serverCoverPreviewBytes != null && _serverCoverPreviewBytes!.isNotEmpty) {
      image = ClipRRect(
        borderRadius: radius,
        child: Image.memory(
          _serverCoverPreviewBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else {
      image = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.primaryDark.withValues(alpha: 0.35),
          borderRadius: radius,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.album_rounded, color: palette.textMuted, size: 36),
      );
    }
    return _highlightWrap(
      palette: palette,
      changed: _coverChanged,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _pickCoverImage,
          borderRadius: radius,
          child: image,
        ),
      ),
    );
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

  bool _isRemoteAudioPath(String path) {
    final p = path.trim().toLowerCase();
    return p.startsWith('http://') || p.startsWith('https://');
  }

  bool _hasLocalAudioFile() {
    if (_audioPath.isEmpty || kIsWeb) return false;
    if (_isRemoteAudioPath(_audioPath)) return false;
    return File(_audioPath).existsSync();
  }

  Future<bool> _audioFileReady() async {
    if (_audioPath.isEmpty) return false;
    if (_serverTrackId != null && !_hasLocalAudioFile()) return true;
    if (kIsWeb) return true;
    return File(_audioPath).existsSync();
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
      final mustUploadAudio =
          id == null || (_hasLocalAudioFile() && _lastUploadedAudioPath != _audioPath);
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
    final artistSuggestions =
        !_authorIsMe ? widget.suggestArtists(_artistCtrl.text) : const <String>[];
    final coRaw = widget.suggestArtists(_coAuthorCtrl.text);
    final coSuggestions =
        coRaw.where((s) => !_coAuthors.contains(s)).take(8).toList();

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
              widget.track == null
                  ? context.t('studio.newTrack')
                  : context.t('studio.editTrack'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
            actions: [
              if (_serverLoggedIn && (_audioPath.isNotEmpty || _serverTrackId != null))
                IconButton(
                  tooltip: context.t('studio.publishToServer'),
                  onPressed: (_parsingMetadata || _serverUploading)
                      ? null
                      : () => unawaited(_publishTrackToServer()),
                  icon: _serverUploading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.accent,
                          ),
                        )
                      : Icon(
                          _serverTrackId != null
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_upload_rounded,
                        ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('common.cancel')),
              ),
              FilledButton(onPressed: _submit, child: Text(context.t('common.save'))),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    studioGlassPanel(
                      context: context,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCoverThumb(palette),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _titleCtrl,
                              decoration: studioGlassFieldDecoration(
                                palette: palette,
                                labelText: context.t('playlists.name'),
                                changed: _titleChanged,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    studioGlassPanel(
                      context: context,
                      child: _highlightWrap(
                        palette: palette,
                        changed: _artistChanged,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (nick.isNotEmpty)
                              CheckboxListTile(
                                value: _authorIsMe,
                                onChanged: (v) => setState(() {
                                  _authorIsMe = v ?? false;
                                  if (_authorIsMe) {
                                    _artistCtrl.text = nick;
                                    _artistCtrl.selection =
                                        TextSelection.collapsed(offset: nick.length);
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
                                changed: _artistChanged,
                              ),
                            ),
                            if (!_authorIsMe && artistSuggestions.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                constraints: const BoxConstraints(maxHeight: 140),
                                decoration: BoxDecoration(
                                  color: palette.primaryDark.withValues(alpha: 0.24),
                                  borderRadius:
                                      BorderRadius.circular(AppConstants.radiusMedium),
                                  border: Border.all(
                                    color: palette.textPrimary.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: artistSuggestions.length,
                                  itemBuilder: (context, i) {
                                    final suggestion = artistSuggestions[i];
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        suggestion,
                                        style: TextStyle(color: palette.textPrimary),
                                      ),
                                      onTap: () {
                                        _artistCtrl.text = suggestion;
                                        _artistCtrl.selection = TextSelection.collapsed(
                                          offset: suggestion.length,
                                        );
                                        setState(() {});
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    studioGlassPanel(
                      context: context,
                      child: _highlightWrap(
                        palette: palette,
                        changed: _coAuthorsChanged,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.t('studio.coAuthors'),
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _coAuthors
                                  .map(
                                    (name) => Chip(
                                      label: Text(name),
                                      onDeleted: () =>
                                          setState(() => _coAuthors.remove(name)),
                                      deleteIconColor: palette.textMuted,
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 8),
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
                                            borderRadius: BorderRadius.circular(
                                              AppConstants.radiusMedium,
                                            ),
                                            border: Border.all(
                                              color: palette.textPrimary.withValues(alpha: 0.08),
                                            ),
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: coSuggestions.length,
                                            itemBuilder: (context, i) {
                                              final suggestion = coSuggestions[i];
                                              return ListTile(
                                                dense: true,
                                                title: Text(
                                                  suggestion,
                                                  style: TextStyle(color: palette.textPrimary),
                                                ),
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
                    const SizedBox(height: 12),
                    studioGlassPanel(
                      context: context,
                      child: _highlightWrap(
                        palette: palette,
                        changed: _genresChanged,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.t('studio.genres'),
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StudioGenrePicker(
                              palette: palette,
                              selected: _genres,
                              onSelectionChanged: (v) => setState(() => _genres = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_isEditing || _hasLocalAudioFile()) ...[
                      const SizedBox(height: 12),
                      studioGlassPanel(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.t('studio.audioFile'),
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _audioPath.isEmpty
                                        ? context.t('studio.notSelected')
                                        : _isRemoteAudioPath(_audioPath)
                                            ? context.t('studio.onServer')
                                            : _audioPath.split(RegExp(r'[/\\]')).last,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: palette.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _parsingMetadata
                                      ? null
                                      : () => unawaited(_pickAudioFile()),
                                  icon: _parsingMetadata
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: palette.accent,
                                          ),
                                        )
                                      : Icon(
                                          _isEditing
                                              ? Icons.swap_horiz_rounded
                                              : Icons.upload_file_rounded,
                                          size: 20,
                                        ),
                                  label: Text(
                                    _parsingMetadata
                                        ? context.t('studio.upload.parsingMetadata')
                                        : _isEditing
                                            ? context.t('playlists.replace')
                                            : context.t('playlists.chooseFile'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_serverUploading) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          context.t('studio.upload.uploading'),
                          style: TextStyle(fontSize: 12, color: palette.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
