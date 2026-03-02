import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../settings/settings_repository.dart';
import 'track.dart';

/// Сервис воспроизведения аудио с поддержкой эквалайзера (Android).
/// На других платформах эквалайзер не применяется.
class AudioPlayerService extends ChangeNotifier {
  AudioPlayerService({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository {
    _initPlayer();
    _listenToPlayer();
  }

  final SettingsRepository _settingsRepository;

  late final AudioPlayer _player;
  AndroidEqualizer? _androidEqualizer;

  Track? _currentTrack;
  bool _isInitialized = false;

  Track? get currentTrack => _currentTrack;
  AudioPlayer get player => _player;
  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  void _initPlayer() {
    if (kIsWeb || !Platform.isAndroid) {
      _player = AudioPlayer();
    } else {
      final eq = AndroidEqualizer();
      _player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [eq]),
      );
      _androidEqualizer = eq;
      eq.setEnabled(true);
    }
    _isInitialized = true;
    notifyListeners();
  }

  void _listenToPlayer() {
    _player.playerStateStream.listen((_) => notifyListeners());
    _player.positionStream.listen((_) => notifyListeners());
  }

  /// Загружает и воспроизводит трек.
  Future<void> playTrack(Track track) async {
    if (!_isInitialized) return;
    _currentTrack = track;
    try {
      await _player.setAudioSource(AudioSource.asset(track.assetPath));
      await _applyEqualizerFromSettings();
      await _player.play();
    } catch (e) {
      _currentTrack = null;
      rethrow;
    }
    notifyListeners();
  }

  /// Продолжает воспроизведение или ставит на паузу.
  Future<void> togglePlayPause() async {
    if (!_isInitialized) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_currentTrack != null) {
        await _player.play();
      }
    }
    notifyListeners();
  }

  /// Продолжает воспроизведение или запускает текущий трек.
  Future<void> play() async {
    if (!_isInitialized) return;
    if (_currentTrack != null) {
      await _player.play();
    }
    notifyListeners();
  }

  Future<void> pause() async {
    if (!_isInitialized) return;
    await _player.pause();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    if (!_isInitialized) return;
    await _player.seek(position);
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _player.stop();
    _currentTrack = null;
    notifyListeners();
  }

  /// Применяет настройки эквалайзера из настроек приложения.
  /// Вызывать при изменении эквалайзера в настройках.
  Future<void> applyEqualizerFromSettings() => _applyEqualizerFromSettings();

  Future<void> _applyEqualizerFromSettings() async {
    if (_androidEqualizer == null) return;
    try {
      await _androidEqualizer!.setEnabled(true);
      final settings = await _settingsRepository.getSettings();
      final params = await _androidEqualizer!.parameters;
      final bands = params.bands;
      final gains = settings.equalizerGains;
      final preamp = settings.equalizerPreamp;

      for (var i = 0; i < bands.length; i++) {
        var gain = i < gains.length ? gains[i] : 0.0;
        if (i == 0) gain += preamp;
        await bands[i].setGain(gain.clamp(params.minDecibels, params.maxDecibels));
      }
    } catch (_) {
      // Игнорируем ошибки эквалайзера
    }
  }

  /// Применяет настройки эквалайзера из переданных gains (для live-обновления в экрана эквалайзера).
  /// Басс-буст (preamp) берётся из настроек и добавляется к первой полосе.
  Future<void> applyEqualizerGains(List<double> gains) async {
    if (_androidEqualizer == null) return;
    try {
      await _androidEqualizer!.setEnabled(true);
      final settings = await _settingsRepository.getSettings();
      final params = await _androidEqualizer!.parameters;
      final bands = params.bands;
      final preamp = settings.equalizerPreamp;

      for (var i = 0; i < bands.length; i++) {
        var gain = i < gains.length ? gains[i] : 0.0;
        if (i == 0) gain += preamp;
        await bands[i].setGain(gain.clamp(params.minDecibels, params.maxDecibels));
      }
    } catch (_) {
      // Игнорируем ошибки эквалайзера
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
