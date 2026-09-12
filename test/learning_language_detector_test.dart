import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/text_language_detector.dart';

void main() {
  test('detects distinctive subtitle scripts offline', () {
    expect(TextLanguageDetector.detect('مرحبا بك كيف حالك اليوم؟ هذا اختبار بسيط للترجمة العربية.'), 'ar');
    expect(TextLanguageDetector.detect('Привет, как дела? Это простой тест русского текста и субтитров.'), 'ru');
  });

  test('detects common English and German subtitle language', () {
    expect(TextLanguageDetector.detect('The thing is that you are not here and I have to know what you want with this.'), 'en');
    expect(TextLanguageDetector.detect('Ich weiß nicht was du meinst. Das ist nicht der Weg und wir haben keine Zeit dafür.'), 'de');
  });

  test('stays unknown for tiny ambiguous samples', () {
    expect(TextLanguageDetector.detect('Hello'), isEmpty);
  });
}
