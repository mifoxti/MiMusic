import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mimusic/core/audio/track.dart';
import 'package:mimusic/core/cache/cache_size.dart';
import 'package:mimusic/core/network/api_config.dart';
import 'package:mimusic/core/offline/offline_download_repository.dart';
import 'package:mimusic/core/settings/app_settings.dart';
import 'package:mimusic/core/settings/settings_repository.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root, {this.nested = false});
  final Directory root;
  final bool nested;
  @override
  Future<String?> getTemporaryPath() async => '${root.path}/cache';
  @override
  Future<String?> getApplicationCachePath() async =>
      '${root.path}/cache${nested ? '/nested' : ''}';
  @override
  Future<String?> getApplicationSupportPath() async => '${root.path}/support';
}

class _Settings implements SettingsRepository {
  _Settings(this.limit);
  final int limit;
  @override
  Future<AppSettings> getSettings() async =>
      AppSettings(cacheLimitBytes: limit);
  @override
  Future<void> saveSettings(AppSettings settings) async {}
}

class _LiveHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform originalPaths;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('mimusic_storage_test_');
    await Directory('${root.path}/cache/nested').create(recursive: true);
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root);
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    PathProviderPlatform.instance = originalPaths;
    await root.delete(recursive: true);
  });

  for (final nested in [false, true]) {
    test('counts overlapping cache roots once (nested=$nested)', () async {
      PathProviderPlatform.instance = _Paths(root, nested: nested);
      await File('${root.path}/cache/a').writeAsBytes(List.filled(100, 1));
      await File(
        '${root.path}/cache/nested/b',
      ).writeAsBytes(List.filled(200, 1));
      expect(await getAppCacheSizeBytes(), 300);
      await clearAppCache();
      expect(await getAppCacheSizeBytes(), 0);
      expect(await Directory('${root.path}/cache').exists(), isTrue);
    });
  }

  Future<void> withServer(Future<void> Function() run) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.method == 'HEAD') {
        request.response.statusCode = 405;
      } else {
        request.response.add(List.filled(10 * 1024 * 1024, 1));
      }
      await request.response.close();
    });
    const channel = MethodChannel('com.example.mimusic/api_config');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => 'http://127.0.0.1:${server.port}',
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await ApiConfig.ensureAndroidDevBaseUrl();
      debugDefaultTargetPlatformOverride = null;
      await HttpOverrides.runWithHttpOverrides(run, _LiveHttp());
    } finally {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
      await server.close(force: true);
    }
  }

  test(
    'rejects and removes actual download larger than remaining capacity',
    () async {
      await withServer(() async {
        final repo = OfflineDownloadRepository(
          settingsRepository: _Settings(9 * 1024 * 1024),
        );
        addTearDown(repo.dispose);
        expect(
          await repo.downloadTrack(
            const Track(assetPath: 'server_track_1', title: 'Test'),
          ),
          DownloadTrackResult.cacheLimitExceeded,
        );
        expect(repo.downloadedTracks, isEmpty);
        expect(await repo.getCombinedCacheUsageBytes(), 0);
        expect(
          await File(
            '${root.path}/support/mimusic_downloads/track_1.bin',
          ).exists(),
          isFalse,
        );
      });
    },
  );

  test(
    'concurrent completed downloads cannot spend the same capacity',
    () async {
      await withServer(() async {
        final repo = OfflineDownloadRepository(
          settingsRepository: _Settings(15 * 1024 * 1024),
        );
        addTearDown(repo.dispose);
        final results = await Future.wait([
          repo.downloadTrack(
            const Track(assetPath: 'server_track_1', title: 'One'),
          ),
          repo.downloadTrack(
            const Track(assetPath: 'server_track_2', title: 'Two'),
          ),
        ]);
        expect(
          results,
          unorderedEquals([
            DownloadTrackResult.success,
            DownloadTrackResult.cacheLimitExceeded,
          ]),
        );
        expect(repo.downloadedTracks, hasLength(1));
        expect(await repo.getCombinedCacheUsageBytes(), 10 * 1024 * 1024);
      });
    },
  );
}
