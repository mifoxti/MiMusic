import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimusic/core/audio/track.dart';
import 'package:mimusic/core/player/player_cover_palette_service.dart';
import 'package:mimusic/core/theme/app_theme.dart';
import 'package:mimusic/features/home/presentation/widgets/floating_mini_player.dart';

void main() {
  testWidgets('mini player separates open, transport swipes and dismiss', (
    tester,
  ) async {
    final palette = PlayerCoverPaletteService();
    addTearDown(palette.dispose);
    var next = 0;
    var previous = 0;
    var dismiss = 0;
    var open = 0;
    var pause = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: FloatingMiniPlayer(
                track: const Track(assetPath: 'test', title: 'Track'),
                playerCoverPalette: palette,
                collaborativeMode: true,
                onNext: () => next++,
                onPrevious: () => previous++,
                onDismiss: () => dismiss++,
                onTap: () => open++,
                onPlayPause: () => pause++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Track'));
    await tester.tap(find.byIcon(Icons.pause_rounded));
    expect(open, 1);
    expect(pause, 1);
    await tester.drag(find.text('Track'), const Offset(-100, 0));
    await tester.pumpAndSettle();
    expect(next, 1);
    expect(previous, 0);
    expect(open, 1);
    await tester.drag(find.text('Track'), const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(previous, 1);
    await tester.drag(find.text('Track'), const Offset(0, 70));
    await tester.pumpAndSettle();
    expect(dismiss, 1);
    expect(pause, 1);
  });

  testWidgets('disabled room gestures never invoke transport or dismiss', (
    tester,
  ) async {
    final palette = PlayerCoverPaletteService();
    addTearDown(palette.dispose);
    var open = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: FloatingMiniPlayer(
                track: const Track(assetPath: 'test', title: 'Track'),
                playerCoverPalette: palette,
                collaborativeMode: true,
                onTap: () => open++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.drag(find.text('Track'), const Offset(-100, 0));
    await tester.drag(find.text('Track'), const Offset(0, 70));
    await tester.pumpAndSettle();
    expect(open, 0);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Track'));
    expect(open, 1);
  });
}
