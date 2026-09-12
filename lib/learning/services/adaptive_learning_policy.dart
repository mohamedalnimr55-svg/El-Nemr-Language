class AdaptiveLearningDecision {
  const AdaptiveLearningDecision({
    required this.showOriginal,
    required this.showTranslation,
    required this.speedFactor,
    required this.reason,
  });

  final bool showOriginal;
  final bool showTranslation;
  final double speedFactor;
  final String reason;
}

class AdaptiveLearningPolicy {
  const AdaptiveLearningPolicy._();

  static AdaptiveLearningDecision decide({
    required double difficulty,
    double? bestScore,
    int attempts = 0,
  }) {
    final d = difficulty.clamp(0.0, 1.0).toDouble();
    final score = bestScore?.clamp(0.0, 1.0).toDouble();

    if (score != null && attempts >= 2 && score >= 0.92) {
      return const AdaptiveLearningDecision(
        showOriginal: false,
        showTranslation: false,
        speedFactor: 1.0,
        reason: 'Mastered · listening challenge',
      );
    }
    if (score != null && score >= 0.76) {
      return const AdaptiveLearningDecision(
        showOriginal: true,
        showTranslation: false,
        speedFactor: 1.0,
        reason: 'Strong · target language only',
      );
    }
    if ((score != null && score < 0.50) || d >= 0.78) {
      return const AdaptiveLearningDecision(
        showOriginal: true,
        showTranslation: true,
        speedFactor: 0.82,
        reason: 'Challenging · full support',
      );
    }
    if (d <= 0.35 && score == null) {
      return const AdaptiveLearningDecision(
        showOriginal: true,
        showTranslation: false,
        speedFactor: 1.0,
        reason: 'Easy · translation hidden',
      );
    }
    return const AdaptiveLearningDecision(
      showOriginal: true,
      showTranslation: true,
      speedFactor: 0.94,
      reason: 'Learning · guided listening',
    );
  }
}
