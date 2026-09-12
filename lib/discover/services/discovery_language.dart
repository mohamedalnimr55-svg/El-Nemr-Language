class DiscoveryLanguage {
  const DiscoveryLanguage({
    required this.code,
    required this.name,
    required this.archiveNames,
  });

  final String code;
  final String name;
  final List<String> archiveNames;
}

const discoveryLanguages = <String, DiscoveryLanguage>{
  'ar': DiscoveryLanguage(code: 'ar', name: 'Arabic', archiveNames: ['Arabic', 'ara', 'ar']),
  'en': DiscoveryLanguage(code: 'en', name: 'English', archiveNames: ['English', 'eng', 'en']),
  'de': DiscoveryLanguage(code: 'de', name: 'German', archiveNames: ['German', 'Deutsch', 'ger', 'deu', 'de']),
  'fr': DiscoveryLanguage(code: 'fr', name: 'French', archiveNames: ['French', 'fra', 'fre', 'fr']),
  'es': DiscoveryLanguage(code: 'es', name: 'Spanish', archiveNames: ['Spanish', 'spa', 'es']),
  'it': DiscoveryLanguage(code: 'it', name: 'Italian', archiveNames: ['Italian', 'ita', 'it']),
  'pt': DiscoveryLanguage(code: 'pt', name: 'Portuguese', archiveNames: ['Portuguese', 'por', 'pt']),
  'ja': DiscoveryLanguage(code: 'ja', name: 'Japanese', archiveNames: ['Japanese', 'jpn', 'ja']),
  'ko': DiscoveryLanguage(code: 'ko', name: 'Korean', archiveNames: ['Korean', 'kor', 'ko']),
  'zh': DiscoveryLanguage(code: 'zh', name: 'Chinese', archiveNames: ['Chinese', 'Mandarin', 'zho', 'chi', 'zh']),
  'ru': DiscoveryLanguage(code: 'ru', name: 'Russian', archiveNames: ['Russian', 'rus', 'ru']),
  'tr': DiscoveryLanguage(code: 'tr', name: 'Turkish', archiveNames: ['Turkish', 'tur', 'tr']),
  'nl': DiscoveryLanguage(code: 'nl', name: 'Dutch', archiveNames: ['Dutch', 'nld', 'dut', 'nl']),
  'sv': DiscoveryLanguage(code: 'sv', name: 'Swedish', archiveNames: ['Swedish', 'swe', 'sv']),
  'pl': DiscoveryLanguage(code: 'pl', name: 'Polish', archiveNames: ['Polish', 'pol', 'pl']),
  'hi': DiscoveryLanguage(code: 'hi', name: 'Hindi', archiveNames: ['Hindi', 'hin', 'hi']),
};

DiscoveryLanguage discoveryLanguageFor(String code) =>
    discoveryLanguages[code.toLowerCase()] ??
    DiscoveryLanguage(code: code.toLowerCase(), name: code.toUpperCase(), archiveNames: [code]);

String normalizeDiscoveryLanguage(Object? value) {
  if (value == null) return '';
  final raw = value is List && value.isNotEmpty ? value.first.toString() : value.toString();
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return '';
  for (final entry in discoveryLanguages.values) {
    if (lower == entry.code || lower == entry.name.toLowerCase()) return entry.code;
    for (final alias in entry.archiveNames) {
      if (lower == alias.toLowerCase()) return entry.code;
    }
  }
  // Tolerate values such as "English; German" by matching a known name.
  for (final entry in discoveryLanguages.values) {
    if (lower.contains(entry.name.toLowerCase())) return entry.code;
  }
  return '';
}
