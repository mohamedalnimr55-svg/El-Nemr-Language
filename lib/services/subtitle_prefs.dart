import 'package:shared_preferences/shared_preferences.dart';

import 'subtitle_languages.dart';

/// Nova-style prefs: reading language (auto-select track), download language
/// (OpenSubtitles `languages` param), and text encoding (codepage).
///
/// Nova stores `system` / 3-letter codes (eng, fre, zho, pob…) and shows full
/// names — never ISO 639-1 in the UI. El-Nemr Language mirrors that.
class SubtitlePrefs {
  static const _legacyLangKey = 'elnemr.prefSubLang'; // old ISO-639-1 `en`
  static const _readingKey = 'elnemr.subReadingLang';
  static const _downloadKey = 'elnemr.subDownloadLang';
  static const _encodingKey = 'elnemr.subEncoding';
  static const _autoKey = 'elnemr.autoFetchSubs';
  static const _autoLearningKey = 'elnemr.autoLearningSubs';

  static Future<String> _migrateIfNeeded(SharedPreferences prefs) async {
    final legacy = prefs.getString(_legacyLangKey);
    if (legacy != null && legacy.isNotEmpty && prefs.getString(_readingKey) == null) {
      final nova = migrateLegacyLangCode(legacy);
      await prefs.setString(_readingKey, nova);
      if (prefs.getString(_downloadKey) == null) await prefs.setString(_downloadKey, nova);
    }
    return legacy ?? '';
  }

  // --- Reading language (which subtitle track to auto-select) ---

  static Future<String> loadReadingLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateIfNeeded(prefs);
    return prefs.getString(_readingKey) ?? 'system';
  }

  static Future<void> saveReadingLanguage(String novaCode) async {
    final prefs = await SharedPreferences.getInstance();
    final code = novaCode.trim().toLowerCase().isEmpty ? 'system' : novaCode.trim().toLowerCase();
    await prefs.setString(_readingKey, _normalize(code));
  }

  // --- Download language (OpenSubtitles) ---

  static Future<String> loadDownloadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateIfNeeded(prefs);
    return prefs.getString(_downloadKey) ?? 'eng';
  }

  static Future<void> saveDownloadLanguage(String novaCode) async {
    final prefs = await SharedPreferences.getInstance();
    final code = novaCode.trim().toLowerCase().isEmpty ? 'eng' : novaCode.trim().toLowerCase();
    await prefs.setString(_downloadKey, _normalize(code));
  }

  // Back-compat: single `loadLanguage` now aliases download language.
  static Future<String> loadLanguage() => loadDownloadLanguage();
  static Future<void> saveLanguage(String lang) => saveDownloadLanguage(migrateLegacyLangCode(lang));

  static String _normalize(String c) {
    if (c == 'system') return 'system';
    return languageForNovaCode(c).novaCode;
  }

  // --- Encoding (Nova codepage list, 0 = Auto) ---

  static Future<int> loadEncoding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_encodingKey) ?? 0;
  }

  static Future<void> saveEncoding(int codepage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_encodingKey, codepage);
  }

  static Future<bool> loadAutoFetch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoKey) ?? false;
  }

  static Future<void> saveAutoFetch(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoKey, v);
  }

  /// Automatically creates learning subtitles from the video's own audio when
  /// no usable learning layers exist. This is local-first and needs no API key.
  static Future<bool> loadAutoLearning() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoLearningKey) ?? true;
  }

  static Future<void> saveAutoLearning(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLearningKey, value);
  }
}
