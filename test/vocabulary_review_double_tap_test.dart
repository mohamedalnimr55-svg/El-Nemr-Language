import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:el_nemr_language/learning/screens/vocabulary_review_screen.dart';
import 'package:el_nemr_language/learning/services/vocabulary_store.dart';

void main() {
  testWidgets('rapid repeated review taps advance a vocabulary card once',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await VocabularyStore.saveWord(
      word: 'bonjour',
      language: 'fr',
      meaning: 'hello',
      context: 'bonjour, comment allez-vous?',
    );
    await tester.pumpWidget(const MaterialApp(home: VocabularyReviewScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reveal meaning'));
    await tester.pump();
    expect(find.text('Good'), findsOneWidget);

    // Two tap callbacks arrive before the persistence future and next frame.
    // The previous implementation could schedule the same item twice.
    await tester.tap(find.text('Good'));
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();

    final saved = await VocabularyStore.load();
    expect(saved, hasLength(1));
    expect(saved.single.repetitions, 1);
    expect(saved.single.intervalDays, 1);
    expect(find.text('You are done for now'), findsOneWidget);
  });
}
