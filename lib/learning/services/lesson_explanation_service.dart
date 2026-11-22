import '../models/learner_profile.dart';
import '../models/learning_models.dart';
import 'ai_language_service.dart';
import 'local_language_coach.dart';

class LessonExplanationResult {
  const LessonExplanationResult({
    required this.text,
    required this.usedLocalCoach,
    this.warning,
  });

  final String text;
  final bool usedLocalCoach;
  final String? warning;
}

/// A configured endpoint is not a guarantee it is online.
/// Learners must still get actionable offline coaching when it fails.
class LessonExplanationService {
  const LessonExplanationService._();

  static Future<LessonExplanationResult> explain({
    required LearningSegment segment,
    required LearnerProfile profile,
    required String sourceLanguage,
    String? previous,
    String? next,
  }) async {
    String? gatewayError;
    if (AiLanguageService.isConfigured) {
      try {
        final text = await AiLanguageService.explainSegment(
          segment: segment,
          profile: profile,
          previous: previous,
          next: next,
        );
        return LessonExplanationResult(text: text, usedLocalCoach: false);
      } catch (error) {
        gatewayError = error.toString();
      }
    }
    final text = await LocalLanguageCoach.explain(
      segment: segment,
      profile: profile,
      sourceLanguage: sourceLanguage,
    );
    return LessonExplanationResult(
      text: text,
      usedLocalCoach: true,
      warning: gatewayError == null
          ? null
          : 'AI Tutor unavailable ($gatewayError). Showing Local Coach instead.',
    );
  }
}
