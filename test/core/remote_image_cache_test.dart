import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Test adapter for the platform interface bundled with path_provider.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mimusic/core/cache/remote_image_cache.dart';
import 'package:mimusic/core/network/api_config.dart';
import 'package:mimusic/core/widgets/cover_image.dart';

class AuditPaths extends PathProviderPlatform {
  AuditPaths(this.root, {this.sameCachePath = false});
  final Directory root;
  final bool sameCachePath;
  @override
  Future<String?> getApplicationCachePath() async => '${root.path}/cache';
  @override
  Future<String?> getTemporaryPath() async =>
      '${root.path}/${sameCachePath ? 'cache' : 'temp'}';
  @override
  Future<String?> getApplicationSupportPath() async => '${root.path}/support';
}

class LiveHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late HttpServer server;
  late String base;
  late Future<void> Function(HttpRequest) response;
  final requests = <String>[];
  final tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6w9sAAAAASUVORK5CYII=',
  );

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mimusic_audit_');
    for (final folder in ['cache', 'temp', 'support']) {
      await Directory('${root.path}/$folder').create();
    }
    PathProviderPlatform.instance = AuditPaths(root);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((request) async {
      requests.add('${request.method} ${request.uri}');
      await response(request);
    });
  });
  setUp(() async {
    requests.clear();
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.example.mimusic/api_config'),
          (call) async => base,
        );
    await ApiConfig.ensureAndroidDevBaseUrl();
    debugDefaultTargetPlatformOverride = null;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });
  tearDownAll(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  test('external cover retains its origin and query', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final external = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? received;
      String? authorization;
      external.listen((request) async {
        received = request.uri.toString();
        authorization = request.headers.value('Authorization');
        request.response.add(tinyPng);
        await request.response.close();
      });
      try {
        final file = await RemoteImageCache.instance.fileForUrl(
          'http://127.0.0.1:${external.port}/external.png?size=40',
          requireAuth: true,
        );
        expect(file, isNotNull);
        expect(received, '/external.png?size=40');
        expect(authorization, isNull);
        expect(requests, isEmpty);
      } finally {
        await external.close(force: true);
      }
    }, LiveHttp());
  });

  test('simultaneous requests for one image share one download', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      response = (request) async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        request.response.add(tinyPng);
        await request.response.close();
      };
      final files = await Future.wait(
        List.generate(
          12,
          (_) => RemoteImageCache.instance.fileForUrl('$base/one-image.png'),
        ),
      );
      expect(files.every((f) => f != null), isTrue);
      expect(requests.length, 1);
    }, LiveHttp());
  });

  test('failed refresh preserves cached bytes and can be retried', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final url = '$base/refresh.png';
      response = (request) async {
        request.response.add(tinyPng);
        await request.response.close();
      };
      final first = await RemoteImageCache.instance.fileForUrl(url);
      expect(first, isNotNull);
      response = (request) async {
        request.response.statusCode = 503;
        await request.response.close();
      };
      final fallback = await RemoteImageCache.instance.fileForUrl(
        url,
        forceRefresh: true,
      );
      expect(await fallback!.readAsBytes(), tinyPng);
      final replacement = [...tinyPng, 1, 2, 3];
      response = (request) async {
        request.response.add(replacement);
        await request.response.close();
      };
      final refreshed = await RemoteImageCache.instance.fileForUrl(
        url,
        forceRefresh: true,
      );
      expect(await refreshed!.readAsBytes(), replacement);
      expect(requests.length, 3);
      final files = await refreshed.parent.list().toList();
      expect(files.where((file) => file.path.endsWith('.tmp')), isEmpty);
    }, LiveHttp());
  });

  testWidgets('older cover response cannot overwrite newer widget URL', (
    tester,
  ) async {
    await tester.runAsync(
      () => HttpOverrides.runWithHttpOverrides(() async {
        final releaseA = Completer<void>();
        final startedA = Completer<void>();
        final finishedB = Completer<void>();
        response = (request) async {
          if (request.uri.path == '/race-a.png') {
            startedA.complete();
            await releaseA.future;
          }
          request.response.add(tinyPng);
          await request.response.close();
          if (request.uri.path == '/race-b.png') finishedB.complete();
        };
        Widget cover(String suffix) => Directionality(
          textDirection: TextDirection.ltr,
          child: buildCoverImage(
            imageUrl: '$base/$suffix',
            width: 40,
            height: 40,
            borderRadius: BorderRadius.zero,
            placeholder: const SizedBox(),
          ),
        );

        await tester.pumpWidget(cover('race-a.png'));
        await startedA.future.timeout(const Duration(seconds: 5));
        await tester.pumpWidget(cover('race-b.png'));
        await finishedB.future.timeout(const Duration(seconds: 5));
        await RemoteImageCache.instance.fileForUrl('$base/race-b.png');
        await tester.pump();
        String imagePath() {
          final provider = tester.widget<Image>(find.byType(Image)).image;
          return ((provider is ResizeImage ? provider.imageProvider : provider)
                  as FileImage).file.path;
        }
        final pathB = imagePath();
        expect(
          pathB,
          endsWith(sha256.convert(utf8.encode('$base/race-b.png')).toString()),
        );
        releaseA.complete();
        await RemoteImageCache.instance.fileForUrl('$base/race-a.png');
        await tester.pump();
        final pathAfterOldResponse = imagePath();
        expect(pathAfterOldResponse, pathB);
        await tester.pumpWidget(const SizedBox());
      }, LiveHttp()),
    );
  });
}
