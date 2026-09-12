import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum VocabularyGrade { again, hard, good, easy }

class VocabularyItem {
  const VocabularyItem({
    required this.key,
    required this.word,
    required this.language,
    required this.meaning,
    required this.context,
    required this.createdAt,
    required this.dueAt,
    this.repetitions = 0,
    this.intervalDays = 0,
    this.ease = 2.5,
    this.seenCount = 1,
  });

  final String key;
  final String word;
  final String language;
  final String meaning;
  final String context;
  final DateTime createdAt;
  final DateTime dueAt;
  final int repetitions;
  final int intervalDays;
  final double ease;
  final int seenCount;

  bool get due => !dueAt.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'key': key,
        'word': word,
        'language': language,
        'meaning': meaning,
        'context': context,
        'createdAt': createdAt.toIso8601String(),
        'dueAt': dueAt.toIso8601String(),
        'repetitions': repetitions,
        'intervalDays': intervalDays,
        'ease': ease,
        'seenCount': seenCount,
      };

  factory VocabularyItem.fromJson(Map<String, dynamic> json) => VocabularyItem(
        key: json['key'] as String? ?? '',
        word: json['word'] as String? ?? '',
        language: json['language'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
        context: json['context'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        dueAt: DateTime.tryParse(json['dueAt'] as String? ?? '') ?? DateTime.now(),
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
        intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 0,
        ease: (json['ease'] as num?)?.toDouble() ?? 2.5,
        seenCount: (json['seenCount'] as num?)?.toInt() ?? 1,
      );

  VocabularyItem reviewed(VocabularyGrade grade) {
    var nextEase = ease;
    var nextRepetitions = repetitions;
    var nextInterval = intervalDays;
    switch (grade) {
      case VocabularyGrade.again:
        nextRepetitions = 0;
        nextInterval = 0;
        nextEase = (ease - 0.2).clamp(1.3, 3.0).toDouble();
        break;
      case VocabularyGrade.hard:
        nextRepetitions += 1;
        nextInterval = intervalDays <= 1 ? 1 : (intervalDays * 1.2).round().clamp(1, 3650).toInt();
        nextEase = (ease - 0.15).clamp(1.3, 3.0).toDouble();
        break;
      case VocabularyGrade.good:
        nextRepetitions += 1;
        nextInterval = switch (nextRepetitions) { 1 => 1, 2 => 3, _ => (intervalDays.clamp(1, 3650) * ease).round().clamp(1, 3650).toInt() };
        break;
      case VocabularyGrade.easy:
        nextRepetitions += 1;
        nextEase = (ease + 0.15).clamp(1.3, 3.0).toDouble();
        nextInterval = switch (nextRepetitions) { 1 => 3, 2 => 7, _ => (intervalDays.clamp(1, 3650) * nextEase * 1.3).round().clamp(1, 3650).toInt() };
        break;
    }
    final due = grade == VocabularyGrade.again
        ? DateTime.now().add(const Duration(minutes: 10))
        : DateTime.now().add(Duration(days: nextInterval));
    return VocabularyItem(
      key: key,
      word: word,
      language: language,
      meaning: meaning,
      context: context,
      createdAt: createdAt,
      dueAt: due,
      repetitions: nextRepetitions,
      intervalDays: nextInterval,
      ease: nextEase,
      seenCount: seenCount,
    );
  }
}

class VocabularyStore {
  const VocabularyStore._();
  static const _prefsKey = 'learning.vocabulary.v1';

  static String keyFor(String word, String language) => '${language.toLowerCase()}:${word.trim().toLowerCase()}';

  static Future<List<VocabularyItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return <VocabularyItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <VocabularyItem>[];
      return decoded.whereType<Map>().map((e) => VocabularyItem.fromJson(Map<String, dynamic>.from(e))).where((e) => e.word.isNotEmpty).toList();
    } catch (_) {
      return <VocabularyItem>[];
    }
  }

  static Future<void> saveWord({
    required String word,
    required String language,
    required String meaning,
    required String context,
  }) async {
    final items = await load();
    final key = keyFor(word, language);
    final index = items.indexWhere((e) => e.key == key);
    final now = DateTime.now();
    final item = index < 0
        ? VocabularyItem(key: key, word: word.trim(), language: language, meaning: meaning, context: context, createdAt: now, dueAt: now)
        : VocabularyItem(
            key: key,
            word: items[index].word,
            language: items[index].language,
            meaning: meaning.isEmpty ? items[index].meaning : meaning,
            context: context.isEmpty ? items[index].context : context,
            createdAt: items[index].createdAt,
            dueAt: items[index].dueAt,
            repetitions: items[index].repetitions,
            intervalDays: items[index].intervalDays,
            ease: items[index].ease,
            seenCount: items[index].seenCount + 1,
          );
    if (index < 0) items.add(item); else items[index] = item;
    await _save(items);
  }

  static Future<List<VocabularyItem>> due() async {
    final items = await load();
    final due = items.where((e) => e.due).toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return due;
  }

  static Future<void> review(String key, VocabularyGrade grade) async {
    final items = await load();
    final index = items.indexWhere((e) => e.key == key);
    if (index < 0) return;
    items[index] = items[index].reviewed(grade);
    await _save(items);
  }

  static Future<void> _save(List<VocabularyItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
