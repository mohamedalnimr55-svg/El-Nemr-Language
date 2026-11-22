/// Normalize recognized/typed text into comparable scoring units.
///
/// Whitespace-delimited scripts (Latin, Arabic, Cyrillic, etc.) keep words.
/// CJK scripts often contain no spaces. Score their characters/syllables
/// instead of treating an entire sentence as one all-or-nothing token.
///
/// This measures transcript similarity, not phoneme or accent accuracy.
List<String> tokenizeLearningText(String value) {
  final normalized = value.toLowerCase();
  final pattern = RegExp(
    r'[a-z0-9_\u00C0-\u024F\u0400-\u052F\u0600-\u06FF\u0750-\u077F]+|[\u3040-\u30FF\u3400-\u9FFF\uAC00-\uD7AF]',
    unicode: true,
  );
  return pattern.allMatches(normalized)
      .map((match) => match.group(0)!)
      .toList(growable: false);
}
