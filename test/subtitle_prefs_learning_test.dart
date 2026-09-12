import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:el_nemr_language/services/subtitle_prefs.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('local auto learning is on by default while online auto search is off', () async {
    expect(await SubtitlePrefs.loadAutoLearning(), isTrue);
    expect(await SubtitlePrefs.loadAutoFetch(), isFalse);
  });

  test('local and online automation preferences are independent', () async {
    await SubtitlePrefs.saveAutoLearning(false);
    await SubtitlePrefs.saveAutoFetch(true);

    expect(await SubtitlePrefs.loadAutoLearning(), isFalse);
    expect(await SubtitlePrefs.loadAutoFetch(), isTrue);
  });
}
