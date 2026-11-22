/// Lightweight offline language hinting for subtitle text.
///
/// This is deliberately conservative: it is only used when neither track
/// metadata nor a language tag in the subtitle file name is available. It
/// avoids sending subtitle text to a network service merely to identify the
/// language. Latin-script languages are scored by common function words;
/// distinctive scripts are detected directly.
class TextLanguageDetector {
  const TextLanguageDetector._();

  static String detect(String text) {
    final sample = text.length > 16000 ? text.substring(0, 16000) : text;
    if (sample.trim().isEmpty) return '';

    final counts = <String, int>{
      'ar': RegExp(r'[\u0600-\u06FF]').allMatches(sample).length,
      'ru': RegExp(r'[\u0400-\u04FF]').allMatches(sample).length,
      'ja': RegExp(r'[\u3040-\u30FF]').allMatches(sample).length,
      'ko': RegExp(r'[\uAC00-\uD7AF]').allMatches(sample).length,
      'zh': RegExp(r'[\u3400-\u9FFF]').allMatches(sample).length,
      'el': RegExp(r'[\u0370-\u03FF]').allMatches(sample).length,
      'he': RegExp(r'[\u0590-\u05FF]').allMatches(sample).length,
      'hy': RegExp(r'[\u0530-\u058F]').allMatches(sample).length,
      'ka': RegExp(r'[\u10A0-\u10FF]').allMatches(sample).length,
      'th': RegExp(r'[\u0E00-\u0E7F]').allMatches(sample).length,
      'lo': RegExp(r'[\u0E80-\u0EFF]').allMatches(sample).length,
      'ta': RegExp(r'[\u0B80-\u0BFF]').allMatches(sample).length,
      'te': RegExp(r'[\u0C00-\u0C7F]').allMatches(sample).length,
      'kn': RegExp(r'[\u0C80-\u0CFF]').allMatches(sample).length,
      'ml': RegExp(r'[\u0D00-\u0D7F]').allMatches(sample).length,
      'km': RegExp(r'[\u1780-\u17FF]').allMatches(sample).length,
      'my': RegExp(r'[\u1000-\u109F]').allMatches(sample).length,
    };
    final letters = RegExp(r'[\p{L}]', unicode: true).allMatches(sample).length;
    if (letters > 0) {
      final kana = counts['ja']!;
      // Japanese can contain *more Han (kanji) than kana*. Choosing only
      // the largest block misidentifies such subtitles as Chinese.
      // Strong kana evidence overrides the shared Han script.
      if (kana >= 8 && kana / letters >= .12) return 'ja';

      final ordered = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top = ordered.first;
      if (top.value >= 8 && top.value / letters >= .18) return top.key;
    }

    final words = sample
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zà-ÿğışçöüß]+', unicode: true), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2200)
        .toList(growable: false);
    if (words.length < 8) return '';

    const markers = <String, Set<String>>{
      'en': {'the','and','you','that','this','with','for','not','are','have','what','your','was','but','can','just'},
      'de': {'der','die','das','und','ist','nicht','ich','du','wir','sie','ein','eine','mit','was','auf','für'},
      'fr': {'le','la','les','de','des','et','est','pas','je','tu','vous','nous','une','un','que','pour'},
      'es': {'el','la','los','las','de','que','y','es','no','yo','tú','usted','una','un','para','con'},
      'it': {'il','la','gli','le','di','che','e','è','non','io','tu','voi','una','un','per','con'},
      'pt': {'o','a','os','as','de','que','e','é','não','eu','você','uma','um','para','com','isso'},
      'tr': {'ve','bir','bu','ben','sen','o','de','da','için','ne','mi','mı','çok','ama','var','yok'},
    };
    final scores = <String, int>{};
    for (final entry in markers.entries) {
      var score = 0;
      for (final word in words) {
        if (entry.value.contains(word)) score++;
      }
      scores[entry.key] = score;
    }
    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty || ranked.first.value < 3) return '';
    if (ranked.length > 1 && ranked.first.value <= ranked[1].value + 1) return '';
    return ranked.first.key;
  }
}
