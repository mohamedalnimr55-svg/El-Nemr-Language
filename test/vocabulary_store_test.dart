import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:el_nemr_language/learning/services/vocabulary_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saving the same word increments exposure instead of duplicating it', () async {
    await VocabularyStore.saveWord(
      word: 'although',
      language: 'en',
      meaning: 'على الرغم من',
      context: 'Although it was late, we stayed.',
    );
    await VocabularyStore.saveWord(
      word: 'Although',
      language: 'EN',
      meaning: 'على الرغم من',
      context: 'Although it rained, we left.',
    );

    final items = await VocabularyStore.load();
    expect(items, hasLength(1));
    expect(items.single.seenCount, 2);
  });

  test('SRS grades move due dates forward predictably', () {
    final now = DateTime.now();
    final item = VocabularyItem(
      key: 'en:test',
      word: 'test',
      language: 'en',
      meaning: 'اختبار',
      context: 'This is a test.',
      createdAt: now,
      dueAt: now,
    );

    final again = item.reviewed(VocabularyGrade.again);
    final good = item.reviewed(VocabularyGrade.good);
    final easy = item.reviewed(VocabularyGrade.easy);

    expect(again.intervalDays, 0);
    expect(again.dueAt.isAfter(now), isTrue);
    expect(good.intervalDays, greaterThanOrEqualTo(1));
    expect(easy.intervalDays, greaterThan(good.intervalDays));
  });
}
