/// Normalize typed/recognized subtitle text into scoring units.
///
/// Languages with whitespace-delimited words (Latin, Greek, Cyrillic,
/// Hebrew, Arabic, Indic and other listed scripts) retain word tokens.
/// Chinese, Japanese, Korean, Thai, Lao, Khmer and Myanmar often have
/// no spaces, so their code points are scored independently to avoid
/// assigning a perfect score to different strings with zero tokens.
///
/// This is transcript similarity, not pronunciation or phoneme scoring.
List<String> tokenizeLearningText(String value) {
  final normalized = value.toLowerCase();
  final pattern = RegExp(
    r'[a-z0-9_\u00C0-\u024F\u0300-\u036F\u0370-\u052F\u0530-\u058F\u0590-\u06FF\u0750-\u077F\u08A0-\u08FF\u0900-\u0DFF\u10A0-\u10FF\u1200-\u137F\u1E00-\u1FFF]+|[\u0E00-\u0EFF\u1000-\u109F\u1780-\u17FF\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF]',
    unicode: true,
  );
  final tokens = pattern.allMatches(normalized)
      .map((match) => match.group(0)!)
      .toList(growable: false);
  // A never-seen writing system or symbol-only subtitle must not silently
  // become empty and get perfect credit against a different nonempty answer.
  final fallback = normalized.trim();
  if (tokens.isEmpty && fallback.isNotEmpty) return <String>[fallback];
  return tokens;
}
