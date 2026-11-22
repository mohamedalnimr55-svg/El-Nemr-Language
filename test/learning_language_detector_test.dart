import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/text_language_detector.dart';

void main() {
  test('detects distinctive subtitle scripts offline', () {
    expect(TextLanguageDetector.detect('مرحبا بك كيف حالك اليوم؟ هذا اختبار بسيط للترجمة العربية.'), 'ar');
    expect(TextLanguageDetector.detect('Привет, как дела? Это простой тест русского текста и субтитров.'), 'ru');
  });

  test('Japanese kana disambiguates subtitles containing mostly kanji', () {
    expect(
      TextLanguageDetector.detect(
        '日本語漢字教科書授業文化音楽歴史映画資料新聞記事今日はどうぞよろしくお願いします。',
      ),
      'ja',
    );
    expect(
      TextLanguageDetector.detect('我正在学习中文，并且今天要观看这部电影的字幕和故事内容。'),
      'zh',
    );
  });

  test('recognizes strong evidence for distinctive language scripts offline', () {
    expect(
      TextLanguageDetector.detect('สวัสดีครับทุกคน วันนี้เราจะเรียนภาษาไทยด้วยกัน'),
      'th',
    );
    expect(
      TextLanguageDetector.detect('שלום לכולם וברוכים הבאים לשיעור החדש שלנו'),
      'he',
    );
    expect(
      TextLanguageDetector.detect('Καλημέρα σας και καλώς ήρθατε στο μάθημα'),
      'el',
    );
    expect(
      TextLanguageDetector.detect('வணக்கம் நண்பர்களே இன்று நாம் தமிழ் கற்கிறோம்'),
      'ta',
    );
    expect(
      TextLanguageDetector.detect('ສະບາຍດີທຸກຄົນ ມື້ນີ້ເຮົາຈະຮຽນພາສາລາວ'),
      'lo',
    );
  });

  test('remains conservative for short ambiguous multilingual clips', () {
    expect(TextLanguageDetector.detect('γειά'), isEmpty);
    expect(TextLanguageDetector.detect('สวัสดี'), isEmpty);
  });

  test('detects common English and German subtitle language', () {
    expect(TextLanguageDetector.detect('The thing is that you are not here and I have to know what you want with this.'), 'en');
    expect(TextLanguageDetector.detect('Ich weiß nicht was du meinst. Das ist nicht der Weg und wir haben keine Zeit dafür.'), 'de');
  });

  test('stays unknown for tiny ambiguous samples', () {
    expect(TextLanguageDetector.detect('Hello'), isEmpty);
  });
}
