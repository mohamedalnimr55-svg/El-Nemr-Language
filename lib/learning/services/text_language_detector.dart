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
    };
    final letters = RegExp(r'[\p{L}]', unicode: true).allMatches(sample).length;
    if (letters > 0) {
      final ordered = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top = ordered.first;
      // Japanese subtitles frequently include Han characters; kana is the
      // stronger signal and therefore wins before the Chinese check below.
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
