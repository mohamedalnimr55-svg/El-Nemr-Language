import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/widgets/learning_studio_sheet.dart';

void main() {
  testWidgets('oversized response is not graded and does not update progress',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final expected = List<String>.generate(600, (i) => 'spoken$i').join(' ');
    final entered = List<String>.generate(600, (i) => 'answer$i').join(' ');
    final segment = LearningSegment(
      id: 'long-dictation',
      start: const Duration(seconds: 1),
      end: const Duration(seconds: 6),
      original: expected,
    );
    const position = Duration(seconds: 3);
    final grades = <double>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 1600,
          child: LearningStudioSheet(
            layers: const [],
            segments: <LearningSegment>[segment],
            position: position,
            positionProvider: () => position,
            mode: LearningMode.listening,
            onModeChanged: (_) {},
            onSeek: (_) {},
            onLayerChanged: (_) {},
            onAddSubtitle: () {},
            onEditLayoutChanged: (_) {},
            editLayout: false,
            onRecordScore: (_, grade) => grades.add(grade),
            onPauseForSpeech: () {},
            profile: const LearnerProfile(
              nativeLanguage: 'en',
              targetLanguage: 'en',
            ),
            onProfileChanged: (_) {},
            onAutoPrepare: () {},
            onRemoveLayer: (_) {},
            onAutoArrange: () {},
            videoKey: 'long-input-test',
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
    await tester.ensureVisible(find.text('Check'));
    await tester.enterText(find.byType(TextField).last, entered);
    await tester.tap(find.text('Check'));
    await tester.pump();

    expect(grades, isEmpty);
    expect(find.textContaining('too long to grade safely'), findsOneWidget);
    expect(find.text('Check'), findsOneWidget,
        reason: 'The learner must be able to correct the overlong response.');

    // A short answer remains gradeable after the user corrects the input.
    await tester.enterText(find.byType(TextField).last, 'short answer');
    await tester.pump();
    expect(find.textContaining('too long to grade safely'), findsNothing);
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(grades, hasLength(1));
    expect(find.text('Graded'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
