// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mimusic/core/audio/mimusic_audio_handler.dart';
import 'package:mimusic/core/history/in_memory_listening_history_repository.dart';
import 'package:mimusic/core/settings/app_settings.dart';
import 'package:mimusic/core/settings/settings_repository.dart';
import 'package:mimusic/main.dart';

class _FakeSettingsRepository implements SettingsRepository {
  @override
  Future<AppSettings> getSettings() async => const AppSettings();

  @override
  Future<void> saveSettings(AppSettings settings) async {}
}

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      MiMusicApp(
        initialSettings: const AppSettings(),
        settingsRepository: _FakeSettingsRepository(),
        audioHandler: MiMusicAudioHandler(),
        listeningHistoryRepository:
            InMemoryListeningHistoryRepository(seedWithLocalAssetDemo: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    // Bottom nav "Music" tab should be visible once home loads
    expect(find.text('Music'), findsOneWidget);
  });
}
