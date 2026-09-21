import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:mimusic/core/audio/mimusic_audio_handler.dart';
import 'package:mimusic/core/audio/audio_transport_coordinator.dart';

class AuditAudioPlatform extends JustAudioPlatform {
  late AuditNativePlayer player;
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async =>
      player = AuditNativePlayer(request.id);
  @override
  Future<DisposePlayerResponse> disposePlayer(
    DisposePlayerRequest request,
  ) async {
    await player.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
    DisposeAllPlayersRequest request,
  ) async => DisposeAllPlayersResponse();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuditAudioPlatform platform;
  late MiMusicAudioHandler handler;
  late JustAudioPlatform originalPlatform;
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.ryanheise.audio_session'),
          (call) async => null,
        );
    originalPlatform = JustAudioPlatform.instance;
    platform = AuditAudioPlatform();
    JustAudioPlatform.instance = platform;
    handler = MiMusicAudioHandler();
  });
  tearDown(() async {
    await handler.disposeHandler();
    JustAudioPlatform.instance = originalPlatform;
  });
  Future<void> load({bool autoPlay = true}) async {
    await handler
        .customAction('playAsset', {
          'path': 'https://test.invalid/a.mp3',
          'itemId': 'server_track_1',
          'title': 'Test',
          'autoPlay': autoPlay,
        })
        .timeout(const Duration(seconds: 2));
  }

  test(
    'playAsset publishes queue and completes while audio is playing',
    () async {
      await load();
      await platform.player.started.future.timeout(const Duration(seconds: 2));
      expect(platform.player.playing, isTrue);
      expect(platform.player.endOfPlayback!.isCompleted, isFalse);
      expect(handler.queue.value.single.id, 'server_track_1');
      await handler.pause();
      await Future<void>.delayed(Duration.zero);
      expect(handler.playbackState.value.playing, isFalse);
    },
  );
  for (final action in ['play', 'roomSyncPlay', 'updateQueuePreserve']) {
    test('$action from paused completes before playback ends', () async {
      await load(autoPlay: false);
      if (action == 'play') {
        await handler.play().timeout(const Duration(seconds: 2));
      } else {
        await handler
            .customAction(
              action,
              action == 'updateQueuePreserve'
                  ? {
                      'path': 'https://test.invalid/a.mp3',
                      'autoPlay': true,
                      'queue': [
                        {
                          'path': 'https://test.invalid/a.mp3',
                          'itemId': 'server_track_1',
                          'title': 'Test',
                        },
                      ],
                    }
                  : null,
            )
            .timeout(const Duration(seconds: 2));
      }
      await platform.player.started.future.timeout(const Duration(seconds: 2));
      expect(platform.player.playing, isTrue);
      expect(platform.player.endOfPlayback!.isCompleted, isFalse);
      expect(handler.queue.value.single.id, 'server_track_1');
      await handler.customAction('roomSyncPause');
      await Future<void>.delayed(Duration.zero);
      expect(handler.playbackState.value.playing, isFalse);
    });
  }
  test(
    'queue refresh while playing completes without waiting for pause',
    () async {
      await load();
      await platform.player.started.future.timeout(const Duration(seconds: 2));
      await handler
          .customAction('updateQueuePreserve', {
            'path': 'https://test.invalid/a.mp3',
            'autoPlay': true,
            'queue': [
              {
                'path': 'https://test.invalid/a.mp3',
                'itemId': 'server_track_1',
                'title': 'Updated',
              },
            ],
          })
          .timeout(const Duration(seconds: 2));
      expect(platform.player.playing, isTrue);
      expect(handler.queue.value.single.title, 'Updated');
      await handler.pause();
    },
  );
  test('asynchronous play errors are observed and published', () async {
    await load();
    await platform.player.started.future.timeout(const Duration(seconds: 2));
    platform.player.endOfPlayback!.completeError(
      StateError('audio output failed'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
      handler.playbackState.value.errorMessage,
      contains('audio output failed'),
    );
    expect(handler.playbackState.value.playing, isFalse);
  });

  test('queue additions and removals retain the loaded playing source', () async {
    await load();
    final player = platform.player;
    await player.started.future;
    final lifetime = player.endOfPlayback;
    final first = {
      'path': 'https://test.invalid/a.mp3',
      'itemId': 'server_track_1',
      'title': 'First',
    };
    final second = {
      'path': 'https://test.invalid/b.mp3',
      'itemId': 'server_track_2',
      'title': 'Second',
    };
    for (final queue in [[first, second], [first]]) {
      await handler.customAction('updateQueuePreserve', {
        'path': first['path'], 'queue': queue, 'autoPlay': true,
      });
      expect(player.loads, 1);
      expect(player.endOfPlayback, same(lifetime));
      expect(player.playing, isTrue);
    }
    expect(player.insertions, 1);
    expect(player.removals, 1);
  });

  test('native automatic next publishes the new track to room transport', () async {
    await handler.customAction('playAsset', {
      'path': 'https://test.invalid/a.mp3', 'title': 'First',
      'queue': [
        {'path': 'https://test.invalid/a.mp3', 'itemId': 'server_track_1', 'title': 'First'},
        {'path': 'https://test.invalid/b.mp3', 'itemId': 'server_track_2', 'title': 'Second'},
      ],
    });
    final changed = AudioTransportCoordinator.instance.events.firstWhere(
      (e) => e.origin == AudioTransportOrigin.engine &&
          e.kind == AudioTransportKind.trackChanged,
    );
    platform.player.emit(index: 1);
    final event = await changed.timeout(const Duration(seconds: 2));
    expect(event.trackId, 'server_track_2');
    expect(handler.mediaItem.value?.id, event.trackId);
    expect(platform.player.loads, 1);
  });
}

class AuditNativePlayer extends AudioPlayerPlatform {
  AuditNativePlayer(super.id);
  final events = StreamController<PlaybackEventMessage>();
  final data = StreamController<PlayerDataMessage>();
  final started = Completer<void>();
  Completer<void>? endOfPlayback;
  bool playing = false;
  int loads = 0;
  int insertions = 0;
  int removals = 0;
  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => events.stream;
  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => data.stream;
  void emit({int index = 0}) => events.add(
    PlaybackEventMessage(
      processingState: ProcessingStateMessage.ready,
      updatePosition: Duration.zero,
      updateTime: DateTime.now(),
      bufferedPosition: const Duration(seconds: 60),
      duration: const Duration(seconds: 60),
      currentIndex: index,
      icyMetadata: null,
      androidAudioSessionId: null,
    ),
  );
  @override
  Future<LoadResponse> load(LoadRequest request) async {
    loads++;
    emit();
    return LoadResponse(duration: const Duration(seconds: 60));
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
    ConcatenatingInsertAllRequest request,
  ) async {
    insertions++;
    return ConcatenatingInsertAllResponse();
  }
  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async {
    removals++;
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    if (playing) return PlayResponse();
    playing = true;
    endOfPlayback = Completer<void>();
    if (!started.isCompleted) started.complete();
    await endOfPlayback!.future;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    playing = false;
    if (endOfPlayback != null && !endOfPlayback!.isCompleted) {
      endOfPlayback!.complete();
    }
    emit();
    return PauseResponse();
  }

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    if (endOfPlayback != null && !endOfPlayback!.isCompleted) {
      endOfPlayback!.complete();
    }
    return DisposeResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();
  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();
  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();
  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();
  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse();
  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async => SetShuffleModeResponse();
  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async => SetShuffleOrderResponse();
  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
    SetAndroidAudioAttributesRequest request,
  ) async => SetAndroidAudioAttributesResponse();
  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();
  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
  setCanUseNetworkResourcesForLiveStreamingWhilePaused(
    SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request,
  ) async => SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();
  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
    SetPreferredPeakBitRateRequest request,
  ) async => SetPreferredPeakBitRateResponse();
  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
    SetAllowsExternalPlaybackRequest request,
  ) async => SetAllowsExternalPlaybackResponse();
}
