import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/widgets/learning_studio_sheet.dart';

void main() {
  testWidgets('translation changes at the same cue ID invalidate stale quiz',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const old = LearningSegment(
      id: 'same-id',
      start: Duration(seconds: 1),
      end: Duration(seconds: 6),
      original: 'Guten Morgen',
      translation: 'Good morning',
    );
    const replacement = LearningSegment(
      id: 'same-id',
      start: Duration(seconds: 1),
      end: Duration(seconds: 6),
      original: 'Guten Morgen',
      translation: 'Good day',
    );
    const position = Duration(seconds: 3);
    final scores = <double>[];

    Widget studio(LearningSegment segment) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 1600,
          child: LearningStudioSheet(
            layers: const [],
            segments: <LearningSegment>[segment],
            position: position,
            positionProvider: () => position,
            mode: LearningMode.test,
            onModeChanged: (_) {},
            onSeek: (_) {},
            onLayerChanged: (_) {},
            onAddSubtitle: () {},
            onEditLayoutChanged: (_) {},
            editLayout: false,
            onRecordScore: (_, score) => scores.add(score),
            onPauseForSpeech: () {},
            profile: const LearnerProfile(
              nativeLanguage: 'en',
              targetLanguage: 'de',
            ),
            onProfileChanged: (_) {},
            onAutoPrepare: () {},
            onRemoveLayer: (_) {},
            onAutoArrange: () {},
            videoKey: 'content-refresh',
            onThreeStepRepeat: () {},
            immersionEnabled: false,
            onImmersionChanged: (_) {},
            smartCoachEnabled: false,
            onSmartCoachChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(studio(old));
    await tester.pump();
    await tester.ensureVisible(find.text('Quiz me'));
    await tester.tap(find.text('Quiz me'));
    await tester.pump();
    expect(find.text('Check'), findsOneWidget);

    // Parent supplies a revised translation but the same cue ID and times.
    // Even before the 250 ms ticker, pressing Check cannot earn stale credit.
    await tester.pumpWidget(studio(replacement));
    await tester.pump();
    await tester.ensureVisible(find.text('Check'));
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(scores, isEmpty,
        reason: 'Old answer cannot grade a new translation sharing its ID');

    // Next ticker must clear the old quiz, not keep a stale prompt visible.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Check'), findsNothing);
    expect(scores, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
