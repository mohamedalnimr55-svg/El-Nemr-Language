import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/widgets/learning_studio_sheet.dart';

void main() {
  testWidgets('revealing a quiz answer disables grading and does not earn credit',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final recordedScores = <double>[];
    const segment = LearningSegment(
      id: 'spoken-1',
      start: Duration(seconds: 1),
      end: Duration(seconds: 6),
      original: 'Where are you going today?',
    );
    const currentPosition = Duration(seconds: 3);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 850,
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
            onRecordScore: (_, score) => recordedScores.add(score),
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
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
