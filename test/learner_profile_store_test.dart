import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:el_nemr_language/learning/models/learner_profile.dart';
import 'package:el_nemr_language/learning/services/learner_profile_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('first run is incomplete until onboarding is saved', () async {
    final initial = await LearnerProfileStore.load();
    expect(initial.onboardingComplete, isFalse);

    const profile = LearnerProfile(
      nativeLanguage: 'ar',
      targetLanguage: 'ko',
      level: 'A2',
      goals: <String>['listening', 'movies'],
      favoriteGenres: <String>['crime', 'comedy'],
      onboardingComplete: true,
    );
    await LearnerProfileStore.save(profile);

    final loaded = await LearnerProfileStore.load();
    expect(loaded.nativeLanguage, 'ar');
    expect(loaded.targetLanguage, 'ko');
    expect(loaded.level, 'A2');
    expect(loaded.goals, contains('listening'));
    expect(loaded.favoriteGenres, contains('crime'));
    expect(loaded.onboardingComplete, isTrue);
  });
}
