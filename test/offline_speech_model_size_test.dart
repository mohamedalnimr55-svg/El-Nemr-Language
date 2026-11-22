import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/offline_speech_model_service.dart';

void main() {
  test('rejects truncated 1 MB Whisper downloads instead of reporting ready', () {
    expect(OfflineSpeechModelService.isPlausibleModelSize(1024 * 1024), isFalse);
  });

  test('the default standard Base model requires a plausible file length', () {
    // LEARNING_WHISPER_MODEL defaults to Base in normal build and CI.
    expect(OfflineSpeechModelService.minimumExpectedModelBytes,
        greaterThan(50 * 1024 * 1024));
    final threshold = OfflineSpeechModelService.minimumExpectedModelBytes;
    expect(OfflineSpeechModelService.isPlausibleModelSize(threshold - 1), isFalse);
    expect(OfflineSpeechModelService.isPlausibleModelSize(threshold), isTrue);
  });
}
