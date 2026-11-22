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

  test('parallel vocabulary saves preserve unique words and exposure counts', () async {
    await Future.wait(List.generate(
      30,
      (i) => VocabularyStore.saveWord(
        word: 'word$i',
        language: 'en',
        meaning: 'Meaning $i',
        context: 'Sentence $i',
      ),
    ));
    var items = await VocabularyStore.load();
    expect(items, hasLength(30));

    await Future.wait(List.generate(
      15,
      (_) => VocabularyStore.saveWord(
        word: 'word0',
        language: 'en',
        meaning: 'Updated',
        context: 'Another exposure',
      ),
    ));
    items = await VocabularyStore.load();
    expect(items, hasLength(30));
    final first = items.singleWhere((item) => item.key == 'en:word0');
    expect(first.seenCount, 16);
    expect(first.meaning, 'Updated');

    await Future.wait(List.generate(
      4,
      (_) => VocabularyStore.review('en:word0', VocabularyGrade.good),
    ));
    items = await VocabularyStore.load();
    expect(
      items.singleWhere((item) => item.key == 'en:word0').repetitions, 4,
    );
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
