class LearnerProfile {
  const LearnerProfile({
    this.nativeLanguage = 'ar',
    this.targetLanguage = 'en',
    this.level = 'A2',
    this.goals = const <String>['listening', 'movies'],
    this.favoriteGenres = const <String>[],
    this.onboardingComplete = false,
  });

  final String nativeLanguage;
  final String targetLanguage;
  final String level;
  final List<String> goals;
  final List<String> favoriteGenres;
  final bool onboardingComplete;

  LearnerProfile copyWith({
    String? nativeLanguage,
    String? targetLanguage,
    String? level,
    List<String>? goals,
    List<String>? favoriteGenres,
    bool? onboardingComplete,
  }) => LearnerProfile(
        nativeLanguage: nativeLanguage ?? this.nativeLanguage,
        targetLanguage: targetLanguage ?? this.targetLanguage,
        level: level ?? this.level,
        goals: goals ?? this.goals,
        favoriteGenres: favoriteGenres ?? this.favoriteGenres,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      );
}
