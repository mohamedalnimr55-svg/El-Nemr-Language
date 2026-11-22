import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/widgets/learning_studio_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('elnemr/speech_coach');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('late speech from an old segment cannot alter the new lesson',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final speech = Completer<String?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
      if (call.method == 'listen') return speech.future;
      if (call.method == 'stop') return Future<void>.value();
      throw PlatformException(code: 'unsupported', message: call.method);
    });
    const segments = <LearningSegment>[
      LearningSegment(
        id: 'first',
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
        original: 'A specific first sentence',
      ),
      LearningSegment(
        id: 'second',
        start: Duration(seconds: 5),
        end: Duration(seconds: 7),
        original: 'A different second sentence',
      ),
    ];
    var position = const Duration(seconds: 2);
    final scores = <double>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 1600,
          child: LearningStudioSheet(
            layers: const [],
            segments: segments,
            position: position,
            positionProvider: () => position,
            mode: LearningMode.speak,
            onModeChanged: (_) {},
            onSeek: (next) => position = next,
            onLayerChanged: (_) {},
            onAddSubtitle: () {},
            onEditLayoutChanged: (_) {},
            editLayout: false,
            onRecordScore: (_, score) => scores.add(score),
            onPauseForSpeech: () {},
            profile: const LearnerProfile(nativeLanguage: 'en', targetLanguage: 'en'),
            onProfileChanged: (_) {},
            onAutoPrepare: () {},
            onRemoveLayer: (_) {},
            onAutoArrange: () {},
            videoKey: 'speech-seek-test',
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
    await tester.ensureVisible(find.text('Speak this line'));
    await tester.tap(find.text('Speak this line'));
    await tester.pump();

    position = const Duration(seconds: 6);
    await tester.pump(const Duration(milliseconds: 300));
    speech.complete('A specific first sentence');
    await tester.pump();

    expect(scores, isEmpty,
        reason: 'A result for a previous subtitle must never earn progress.');
    expect(find.textContaining('Transcript match'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
