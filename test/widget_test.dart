import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:el_nemr_language/app.dart';
import 'package:el_nemr_language/l10n/app_localizations.dart';
import 'package:el_nemr_language/models/video_item.dart';
import 'package:el_nemr_language/screens/file_browser_screen.dart';
import 'package:el_nemr_language/screens/player_screen.dart';
import 'package:el_nemr_language/widgets/format_chip.dart';

void main() {
  setUp(() {
    // Keep root-shell widget tests deterministic. The real app shows a TMDB
    // first-run hint, which would otherwise cover the navigation and make
    // these shell/layout tests fail for reasons unrelated to their purpose.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'elnemr.tmdbHintShown': true,
      'learning.profile.onboardingComplete': true,
    });
  });

  testWidgets('First launch is gated by learning onboarding', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'elnemr.tmdbHintShown': true,
    });

    await tester.pumpWidget(const ElNemrLanguageApp());
    await tester.pumpAndSettle();

    expect(find.text('El-Nemr Language'), findsOneWidget);
    expect(find.text('What is your main language?'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('App shows library and settings shell', (tester) async {
    await tester.pumpWidget(const ElNemrLanguageApp());
    await tester.pumpAndSettle();

    expect(find.text('El-Nemr Language'), findsOneWidget);
    expect(find.textContaining('Continue watching'), findsOneWidget);
    expect(find.textContaining('No videos yet'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Switching to profile tab shows settings', (tester) async {
    await tester.pumpWidget(const ElNemrLanguageApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Local AI & learning subtitles'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('About'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('About'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Version'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Version'), findsOneWidget);
  });

  testWidgets('Clear cache shows a confirmation and confirms', (tester) async {
    // The elnemr/cache channel is only registered natively; in the test
    // binding an unhandled channel never completes, so mock it to return 0.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('elnemr/cache'),
      (call) async => 0,
    );
    await tester.pumpWidget(const ElNemrLanguageApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Clear cache'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();

    expect(find.text('Clear cache?'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('Cache cleared'), findsOneWidget);
    expect(find.text('Cached images and temporary files cleared'), findsOneWidget);
  });

  testWidgets('Tapping a video opens the player with codec chips', (
    tester,
  ) async {
    const video = VideoItem(
      id: '1',
      title: 'Sonic Anthem (IMAX)',
      path: '/storage/emulated/0/Download/video/test.mkv',
      duration: Duration(seconds: 50),
      videoCodec: 'h264',
      audioCodec: 'dts_hd',
      audioProfile: 'MA',
      audioChannels: '5.1',
    );
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PlayerScreen(video: video),
    ));

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(find.byType(FormatChip), findsWidgets);
    expect(find.text('DTS-HD MA 5.1'), findsOneWidget);
  });

  testWidgets('No overflow on small phone screen', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ElNemrLanguageApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('No overflow on tablet screen', (tester) async {
    tester.view.physicalSize = const Size(1024 * 2, 1366 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ElNemrLanguageApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('No overflow on landscape phone', (tester) async {
    tester.view.physicalSize = const Size(640 * 2, 360 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ElNemrLanguageApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('+ menu shows every entry in phone landscape', (tester) async {
    // Default modal bottom sheets cap at 9/16 of screen height; in phone
    // landscape that clipped the tail of the + menu (regression: the sheet
    // used a non-scrollable Wrap). The sheet is now scroll-controlled.
    tester.view.physicalSize = const Size(800 * 2, 360 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ElNemrLanguageApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Top-level entries are always visible.
    expect(find.text('Add folder to library'), findsOneWidget);
    expect(find.text('Internal storage'), findsOneWidget);

    // Network entries live inside a collapsed ExpansionTile — expand it.
    await tester.tap(find.text('Network sources'));
    await tester.pumpAndSettle();

    expect(find.text('WebDAV'), findsOneWidget);
    expect(find.text('FTP / SFTP'), findsOneWidget);
    expect(find.text('Jellyfin'), findsOneWidget);
    expect(find.text('SMB / NAS'), findsOneWidget);
    expect(find.text('DLNA'), findsOneWidget);
    expect(find.text('Play URL'), findsOneWidget);
  });

  testWidgets('No overflow with large text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const ElNemrLanguageApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('File browser back button goes up one folder at a time', (
    tester,
  ) async {
    const channel = MethodChannel('elnemr/files');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        switch (call.method) {
          case 'getStorageRoots':
            return [
              {
                'name': 'Internal storage',
                'path': '/storage/emulated/0',
                'isDirectory': true,
                'size': 0,
              },
            ];
          case 'listDirectory':
            Map<String, dynamic> dir(String name, String path) => {
                  'name': name,
                  'path': path,
                  'isDirectory': true,
                  'size': 0,
                };
            return switch (call.arguments['path'] as String) {
              '/storage/emulated/0' =>
                [dir('Download', '/storage/emulated/0/Download')],
              '/storage/emulated/0/Download' =>
                [dir('Movies', '/storage/emulated/0/Download/Movies')],
              _ => <Map<String, dynamic>>[],
            };
          default:
            return null;
        }
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: FileBrowserScreen()));
    await tester.pumpAndSettle();

    // Roots list.
    expect(find.text('Browse files'), findsOneWidget);
    expect(find.text('Internal storage'), findsOneWidget);

    // Enter internal storage -> Download listing.
    await tester.tap(find.text('Internal storage'));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsOneWidget);

    // Enter Download -> Movies listing.
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();
    expect(find.text('Movies'), findsOneWidget);

    // Enter Movies -> empty folder.
    await tester.tap(find.text('Movies'));
    await tester.pumpAndSettle();

    // Back -> Download listing (parent of Movies is a plain folder).
    await tester.tap(find.byTooltip('Up'));
    await tester.pumpAndSettle();
    expect(find.text('Movies'), findsOneWidget);

    // Back -> internal storage contents (parent of Download IS the root):
    // must NOT skip to the 'Browse files' roots list.
    await tester.tap(find.byTooltip('Up'));
    await tester.pumpAndSettle();
    expect(find.text('Browse files'), findsNothing);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Internal storage'), findsNothing);

    // Back -> roots list.
    await tester.tap(find.byTooltip('Up'));
    await tester.pumpAndSettle();
    expect(find.text('Browse files'), findsOneWidget);
  });
}
