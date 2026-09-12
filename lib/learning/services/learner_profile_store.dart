import 'package:shared_preferences/shared_preferences.dart';
import '../models/learner_profile.dart';

class LearnerProfileStore {
  const LearnerProfileStore._();
  static const _native = 'learning.profile.nativeLanguage';
  static const _target = 'learning.profile.targetLanguage';
  static const _level = 'learning.profile.level';
  static const _goals = 'learning.profile.goals';
  static const _genres = 'learning.profile.favoriteGenres';
  static const _complete = 'learning.profile.onboardingComplete';

  static Future<LearnerProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LearnerProfile(
      nativeLanguage: prefs.getString(_native) ?? 'ar',
      targetLanguage: prefs.getString(_target) ?? 'en',
      level: prefs.getString(_level) ?? 'A2',
      goals: prefs.getStringList(_goals) ?? const <String>['listening', 'movies'],
      favoriteGenres: prefs.getStringList(_genres) ?? const <String>[],
      onboardingComplete: prefs.getBool(_complete) ?? false,
    );
  }

  static Future<void> save(LearnerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_native, profile.nativeLanguage),
      prefs.setString(_target, profile.targetLanguage),
      prefs.setString(_level, profile.level),
      prefs.setStringList(_goals, profile.goals),
      prefs.setStringList(_genres, profile.favoriteGenres),
      prefs.setBool(_complete, profile.onboardingComplete),
    ]);
  }

  static Future<void> resetOnboarding() async {
    final profile = await load();
    await save(profile.copyWith(onboardingComplete: false));
  }
}
