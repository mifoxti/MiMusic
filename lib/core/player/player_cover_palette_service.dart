import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/audio_player_service.dart';
import '../audio/track.dart';
import 'player_cover_corner_extractor.dart';
import 'player_cover_glass_colors.dart';
import 'player_cover_image_provider.dart';

/// Палитра стекла плеера: 4 угла обложки + байты обложки для фона.
class PlayerCoverPaletteService extends ChangeNotifier {
  PlayerCoverGlassColors _display = PlayerCoverGlassColors.fallback;
  PlayerCoverGlassColors _target = PlayerCoverGlassColors.fallback;
  Uint8List? _displayCoverBytes;

  final Map<String, PlayerCoverGlassColors> _cache = {};
  final Map<String, Uint8List> _coverBytesCache = {};
  AudioPlayerService? _audio;
  int _generation = 0;
  Timer? _animTimer;
  String? _lastTrackKey;
  String? _loadingKey;

  PlayerCoverGlassColors get colors => _display;
  Uint8List? get coverBytes => _displayCoverBytes;

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
    _displayCoverBytes = null;
    _display = PlayerCoverGlassColors.fallback;
    _target = PlayerCoverGlassColors.fallback;
    notifyListeners();
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
      _displayCoverBytes = null;
      _setTarget(PlayerCoverGlassColors.fallback);
      return;
    }
    final key = coverPaletteCacheKey(track);
    if (key == _loadingKey) return;
    if (key == _lastTrackKey &&
        _displayCoverBytes != null &&
        !_display.isCloseTo(PlayerCoverGlassColors.fallback)) {
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
        _lastTrackKey = cacheKey;
        _displayCoverBytes = cachedBytes;
        _setTarget(cached);
        return;
      }

      final bytes = await loadCoverBytesForTrack(track);
      if (gen != _generation) return;
      if (bytes == null || bytes.isEmpty) return;

      final extracted = await extractCornerColorsFromBytes(bytes);
      if (gen != _generation) return;
      if (extracted == null) return;

      final colors = extracted.softened(strength: 0.88);
      _cache[cacheKey] = colors;
      _coverBytesCache[cacheKey] = bytes;
      if (_cache.length > 48) {
        final old = _cache.keys.first;
        _cache.remove(old);
        _coverBytesCache.remove(old);
      }
      _lastTrackKey = cacheKey;
      _displayCoverBytes = bytes;
      _setTarget(colors);
    } catch (_) {
      // Оставляем текущую палитру.
    } finally {
      if (_loadingKey == cacheKey) _loadingKey = null;
    }
  }

  void _setTarget(PlayerCoverGlassColors target) {
    _target = target;
    _animTimer?.cancel();
    if (_display.isCloseTo(_target)) return;

    _animTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _display = PlayerCoverGlassColors.lerp(_display, _target, 0.12);
      notifyListeners();
      if (_display.isCloseTo(_target)) {
        _display = _target;
        _animTimer?.cancel();
        _animTimer = null;
        notifyListeners();
      }
    });
    notifyListeners();
  }
}
