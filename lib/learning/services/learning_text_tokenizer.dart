/// Normalize typed/recognized subtitle text into scoring units.
///
/// Whitespace-delimited languages keep words together, including any Unicode
/// letters, combining marks and numbers (not just a fixed list of scripts).
/// Chinese, Japanese, Korean, Thai, Lao, Khmer and Myanmar are scored by
/// codepoint where text often has no spaces. Symbols/emoji count as separate
/// units so different mixed text cannot accidentally receive 100% credit.
///
/// This estimates transcript similarity, not pronunciation or phonemes.
final RegExp _unspacedScript = RegExp(
  r'[\u0E00-\u0EFF\u1000-\u109F\u1780-\u17FF\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF]',
  unicode: true,
);
final RegExp _wordCharacter = RegExp(r'[\p{L}\p{M}\p{N}_]', unicode: true);
final RegExp _symbolCharacter = RegExp(r'[\p{S}]', unicode: true);

List<String> tokenizeLearningText(String value) {
  final normalized = value.toLowerCase();
  final units = <String>[];
  var word = StringBuffer();

  void flushWord() {
    final token = word.toString();
    if (token.isNotEmpty) units.add(token);
    word = StringBuffer();
  }

  // Rune iteration preserves supplementary-plane letters and symbols.
  for (final rune in normalized.runes) {
    final char = String.fromCharCode(rune);
    if (_unspacedScript.hasMatch(char)) {
      flushWord();
      units.add(char);
    } else if (_wordCharacter.hasMatch(char)) {
      word.write(char);
    } else if (_symbolCharacter.hasMatch(char)) {
      flushWord();
      units.add(char);
    } else {
      flushWord();
    }
  }
  flushWord();

  // Keep a nonempty unknown string from being interpreted as an empty
  // answer and incorrectly receiving the maximum score.
  final fallback = normalized.trim();
  if (units.isEmpty && fallback.isNotEmpty) return <String>[fallback];
  return units;
}
