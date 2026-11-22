import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/services/video_flashcard_store.dart';
import 'package:el_nemr_language/learning/widgets/learning_studio_sheet.dart';

void main() {
  testWidgets('review keeps its question after seeking to a due subtitle',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const segments = <LearningSegment>[
      LearningSegment(
        id: 'before',
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
        original: 'We start here.',
      ),
      LearningSegment(
        id: 'due',
        start: Duration(seconds: 5),
        end: Duration(seconds: 7),
        original: 'We meet again tomorrow.',
      ),
    ];
    await VideoFlashcardStore.toggle('due-review-test', segments[1]);
    var position = const Duration(seconds: 2);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 1600,
          child: LearningStudioSheet(
            layers: const [],
            segments: segments,
            position: position,
            positionProvider: () => position,
            mode: LearningMode.test,
            onModeChanged: (_) {},
            onSeek: (next) => position = next,
            onLayerChanged: (_) {},
            onAddSubtitle: () {},
            onEditLayoutChanged: (_) {},
            editLayout: false,
            onRecordScore: (_, __) {},
            onPauseForSpeech: () {},
            profile: const LearnerProfile(nativeLanguage: 'en', targetLanguage: 'en'),
            onProfileChanged: (_) {},
            onAutoPrepare: () {},
            onRemoveLayer: (_) {},
            onAutoArrange: () {},
            videoKey: 'due-review-test',
            onThreeStepRepeat: () {},
            immersionEnabled: false,
            onImmersionChanged: (_) {},
            smartCoachEnabled: false,
            onSmartCoachChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.ensureVisible(find.text('Review'));
    await tester.tap(find.text('Review'));
    await tester.pump();
    expect(position, segments[1].start);
    expect(find.text('Check'), findsOneWidget);

    // The old implementation reset _question on the next 250ms tick.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Check'), findsOneWidget,
        reason: 'Review must not lose its quiz when the player seeks.');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
