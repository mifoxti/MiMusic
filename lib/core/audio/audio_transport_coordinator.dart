import 'dart:async';

import 'package:flutter/foundation.dart';

/// The single, small transport event bus shared by the audio engine and UI.
/// Events carry an origin and command id so a remote echo can be ignored by
/// consumers without guessing where it came from.
enum AudioTransportOrigin { ui, notification, headset, colisten, engine }

enum AudioTransportKind { play, pause, seek, next, previous, trackChanged }

@immutable
class AudioTransportEvent {
  const AudioTransportEvent({
    required this.kind,
    required this.origin,
    required this.commandId,
    required this.generation,
    this.position,
    this.trackId,
  });
  final AudioTransportKind kind;
  final AudioTransportOrigin origin;
  final String commandId;
  final int generation;
  final Duration? position;
  final String? trackId;
}

class AudioTransportCoordinator {
  AudioTransportCoordinator._();
  static final AudioTransportCoordinator instance =
      AudioTransportCoordinator._();

  final StreamController<AudioTransportEvent> _events =
      StreamController<AudioTransportEvent>.broadcast();
  final Set<String> _recentCommands = <String>{};
  int _generation = 0;

  Stream<AudioTransportEvent> get events => _events.stream;
  int get generation => _generation;
  int beginTrackGeneration() => ++_generation;

  String emit(
    AudioTransportKind kind, {
    AudioTransportOrigin origin = AudioTransportOrigin.engine,
    String? commandId,
    Duration? position,
    String? trackId,
    int? generation,
  }) {
    final id =
        commandId ?? '${DateTime.now().microsecondsSinceEpoch}-${_generation}';
    if (_recentCommands.add(id)) {
      if (_recentCommands.length > 128)
        _recentCommands.remove(_recentCommands.first);
      _events.add(
        AudioTransportEvent(
          kind: kind,
          origin: origin,
          commandId: id,
          generation: generation ?? _generation,
          position: position,
          trackId: trackId,
        ),
      );
    }
    return id;
  }

  bool isCurrent(int generation) => generation == _generation;
}
