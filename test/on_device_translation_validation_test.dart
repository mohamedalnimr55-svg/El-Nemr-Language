import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/on_device_translation_service.dart';

void main() {
  test('accepts and trims actual translated text', () {
    expect(
      OnDeviceTranslationService.requireNonemptyTranslation('  مرحبًا بك  '),
      'مرحبًا بك',
    );
  });

  test('rejects blank native translation instead of saving silent cues', () {
    for (final invalid in <String>['', ' ', '\n\t ']) {
      expect(
        () => OnDeviceTranslationService.requireNonemptyTranslation(invalid),
        throwsA(isA<OnDeviceTranslationException>()),
      );
    }
  });
}
