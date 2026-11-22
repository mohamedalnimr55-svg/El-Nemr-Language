import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/widgets/learning_studio_sheet.dart';

void main() {
  testWidgets('revealing a quiz answer disables grading and does not earn credit',
      (tester) async {
    // The Learning Studio is a tall bottom sheet. Flutter's default
    // 800×600 test viewport can put its buttons outside the test root even
    // after scrolling the internal DraggableScrollableSheet.
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final recordedScores = <double>[];
    final recordedSegments = <LearningSegment>[];
    const segment = LearningSegment(
      id: 'spoken-1',
      start: Duration(seconds: 1),
      end: Duration(seconds: 6),
      original: 'Where are you going today?',
      translation: '¿A dónde vas hoy?',
    );
    const currentPosition = Duration(seconds: 3);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 1600,
          child: LearningStudioSheet(
            layers: const [],
            segments: const <LearningSegment>[segment],
            position: currentPosition,
            positionProvider: () => currentPosition,
            mode: LearningMode.test,
            onModeChanged: (_) {},
            onSeek: (_) {},
            onLayerChanged: (_) {},
            onAddSubtitle: () {},
            onEditLayoutChanged: (_) {},
            editLayout: false,
            onRecordScore: (captured, score) {
              recordedSegments.add(captured);
              recordedScores.add(score);
            },
            onPauseForSpeech: () {},
            profile: const LearnerProfile(
              nativeLanguage: 'en',
              targetLanguage: 'en',
            ),
            onProfileChanged: (_) {},
            onAutoPrepare: () {},
            onRemoveLayer: (_) {},
            onAutoArrange: () {},
            videoKey: 'reveal-test-video',
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

    await tester.ensureVisible(find.text('Quiz me'));
    await tester.tap(find.text('Quiz me'));
    await tester.pump();

    await tester.ensureVisible(find.text('Show answer'));
    await tester.tap(find.text('Show answer'));
    await tester.pump();

    final revealed = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Revealed · not graded'),
    );
    expect(revealed.onPressed, isNull);
    expect(recordedScores, isEmpty);

    // A fresh question may be graded, but two rapid Check events must not
    // register two progress attempts or schedule two flashcard reviews.
    await tester.ensureVisible(find.text('Quiz me'));
    await tester.tap(find.text('Quiz me'));
    await tester.pump();
    await tester.ensureVisible(find.text('Check'));
    await tester.enterText(find.byType(TextField).last, 'my answer');
    await tester.tap(find.text('Check'));
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(recordedScores, hasLength(1));
    expect(recordedSegments, hasLength(1));
    expect(recordedSegments.single.id, segment.id);
    expect(recordedSegments.single.original, segment.original);
    expect(recordedSegments.single.translation, segment.translation);
    final graded = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Graded'),
    );
    expect(graded.onPressed, isNull);

    await tester.tap(find.text('Show answer'));
    await tester.pump();
    expect(recordedScores, hasLength(1),
        reason: 'Showing the correct answer after grading must not add attempts.');
    expect(find.text('Graded'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
