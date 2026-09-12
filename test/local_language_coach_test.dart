import 'package:flutter_test/flutter_test.dart';

import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/models/learning_models.dart';
import 'package:el_nemr_language/learning/services/local_language_coach.dart';

void main() {
  test('local coach provides useful English listening/grammar help without an LLM', () async {
    const segment = LearningSegment(
      id: '1',
      start: Duration.zero,
      end: Duration(seconds: 3),
      original: "I've been meaning to call you.",
      translation: 'كنت أنوي الاتصال بك.',
    );
    const profile = LearnerProfile(
      nativeLanguage: 'ar',
      targetLanguage: 'en',
      onboardingComplete: true,
    );

    final explanation = await LocalLanguageCoach.explain(
      segment: segment,
      profile: profile,
      sourceLanguage: 'en',
    );

    expect(explanation, contains('كنت أنوي الاتصال بك'));
    expect(explanation, contains('have/has been'));
    expect(explanation, isNot(contains('API')));
  });
}
