import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/audio_player_service.dart';
import '../audio/track.dart';
import 'player_cover_corner_extractor.dart';
import 'player_cover_glass_colors.dart';
import 'player_cover_image_provider.dart';

/// Палитра стекла плеера: 4 угла обложки + байты обложки для фона.
///
/// Смена оформления — кроссфейд двух готовых слоёв (без смешивания RGB/HSL).
class PlayerCoverPaletteService extends ChangeNotifier {
  PlayerCoverGlassColors _shown = PlayerCoverGlassColors.fallback;
  Uint8List? _shownCover;

  PlayerCoverGlassColors? _fromColors;
  PlayerCoverGlassColors? _toColors;
  Uint8List? _fromCover;
  Uint8List? _toCover;
  double _crossfadeRaw = 1.0;
  double _shellCrossfade = 1.0;

  final Map<String, PlayerCoverGlassColors> _cache = {};
  final Map<String, Uint8List> _coverBytesCache = {};
  AudioPlayerService? _audio;
  int _generation = 0;
  Timer? _animTimer;
  String? _lastTrackKey;
  String? _loadingKey;

  static const _frameMs = 16;
  static const _crossfadeMs = 380;
  static const _maxCacheEntries = 48;

  /// Палитра для акцентов UI (целевая при переходе).
  PlayerCoverGlassColors get colors => _toColors ?? _shown;

  bool get isCrossfading => _fromColors != null;

  PlayerCoverGlassColors get shellBackColors => _fromColors ?? _shown;
  PlayerCoverGlassColors get shellFrontColors => _toColors ?? _shown;
  double get shellCrossfade => _shellCrossfade;
  Uint8List? get shellBackCover => _fromCover ?? _shownCover;
  Uint8List? get shellFrontCover => _toCover ?? _shownCover;

  /// Совместимость: активная обложка нижнего слоя.
  Uint8List? get coverBytes => shellBackCover;

  void attach(AudioPlayerService audio) {
    _audio?.removeListener(_onAudioChanged);
    _audio = audio;
    audio.addListener(_onAudioChanged);
    _onAudioChanged();
  }

  void detach() {
    _audio?.removeListener(_onAudioChanged);
    _audio = null;
    _animTimer?.cancel();
    _animTimer = null;
    _generation++;
    _lastTrackKey = null;
    _loadingKey = null;
    _resetTo(PlayerCoverGlassColors.fallback, coverBytes: null);
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  void _onAudioChanged() {
    final track = _audio?.currentTrack;
    if (track == null) {
      _lastTrackKey = null;
      _loadingKey = null;
      _beginCrossfade(PlayerCoverGlassColors.fallback, coverBytes: null);
      return;
    }
    final key = coverPaletteCacheKey(track);
    if (key == _loadingKey) return;
    if (key == _lastTrackKey &&
        _shownCover != null &&
        !_shown.isCloseTo(PlayerCoverGlassColors.fallback)) {
      return;
    }
    unawaited(_loadForTrack(track, key));
  }

  Future<void> _loadForTrack(Track track, String cacheKey) async {
    _loadingKey = cacheKey;
    final gen = ++_generation;
    try {
      final cached = _cache[cacheKey];
      final cachedBytes = _coverBytesCache[cacheKey];
      if (cached != null && cachedBytes != null) {
        if (gen != _generation) return;
        _touchCache(cacheKey);
        _beginCrossfade(cached, cacheKey: cacheKey, coverBytes: cachedBytes);
        return;
      }

      final bytes = await loadCoverBytesForTrack(track);
      if (gen != _generation) return;
      if (bytes == null || bytes.isEmpty) return;

      final extracted = await extractCornerColorsFromBytes(bytes);
      if (gen != _generation) return;
      if (extracted == null) return;

      final palette = extracted.softened(strength: 0.88);
      _rememberCache(cacheKey, palette, bytes);
      _beginCrossfade(palette, cacheKey: cacheKey, coverBytes: bytes);
    } catch (_) {
      // Оставляем текущее оформление.
    } finally {
      if (_loadingKey == cacheKey) _loadingKey = null;
    }
  }

  void _rememberCache(
    String cacheKey,
    PlayerCoverGlassColors palette,
    Uint8List bytes,
  ) {
    _cache.remove(cacheKey);
    _coverBytesCache.remove(cacheKey);
    _cache[cacheKey] = palette;
    _coverBytesCache[cacheKey] = bytes;
    while (_cache.length > _maxCacheEntries) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      _coverBytesCache.remove(oldest);
    }
  }

  void _touchCache(String cacheKey) {
    final colors = _cache.remove(cacheKey);
    final bytes = _coverBytesCache.remove(cacheKey);
    if (colors == null || bytes == null) return;
    _cache[cacheKey] = colors;
    _coverBytesCache[cacheKey] = bytes;
  }

  void _setCrossfadeRaw(double value) {
    final raw = value.clamp(0.0, 1.0);
    _crossfadeRaw = raw;
    _shellCrossfade = Curves.easeInOut.transform(raw);
  }

  void _beginCrossfade(
    PlayerCoverGlassColors target, {
    String? cacheKey,
    Uint8List? coverBytes,
  }) {
    if (cacheKey != null) _lastTrackKey = cacheKey;

    _animTimer?.cancel();
    _settleInFlightCrossfade();

    final nextCover = coverBytes ?? _shownCover;
    if (target.isCloseTo(_shown) &&
        (nextCover == null || nextCover == _shownCover)) {
      _resetTo(target, coverBytes: nextCover);
      return;
    }

    _fromColors = _shown;
    _fromCover = _shownCover;
    _toColors = target;
    _toCover = nextCover;
    _setCrossfadeRaw(0.0);

    final steps = (_crossfadeMs / _frameMs).ceil().clamp(1, 120);
    var step = 0;
    _animTimer = Timer.periodic(const Duration(milliseconds: _frameMs), (_) {
      step++;
      _setCrossfadeRaw(step / steps);
      if (_crossfadeRaw >= 1.0) {
        _animTimer?.cancel();
        _animTimer = null;
        notifyListeners();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (_fromColors == null || _toColors != target) return;
          _resetTo(target, coverBytes: nextCover);
        });
        return;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void _settleInFlightCrossfade() {
    if (_toColors == null || _crossfadeRaw >= 1.0) return;
    if (_crossfadeRaw >= 0.5) {
      _shown = _toColors!;
      _shownCover = _toCover;
    } else if (_fromColors != null) {
      _shown = _fromColors!;
      _shownCover = _fromCover;
    }
    _fromColors = null;
    _toColors = null;
    _fromCover = null;
    _toCover = null;
    _setCrossfadeRaw(1.0);
  }

  void _resetTo(PlayerCoverGlassColors target, {Uint8List? coverBytes}) {
    _animTimer?.cancel();
    _animTimer = null;

    final nextCover = target.isCloseTo(PlayerCoverGlassColors.fallback)
        ? null
        : coverBytes;
    final unchanged =
        _shown.isCloseTo(target) &&
        _shownCover == nextCover &&
        _fromColors == null &&
        _toColors == null &&
        _crossfadeRaw >= 1.0;
    if (unchanged) return;

    _shown = target;
    _shownCover = nextCover;
    _fromColors = null;
    _toColors = null;
    _fromCover = null;
    _toCover = null;
    _setCrossfadeRaw(1.0);
    notifyListeners();
  }
}
