import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/subtitle_cue.dart';
import '../models/learning_models.dart';
import '../models/learner_profile.dart';

class AiLanguageException implements Exception {
  const AiLanguageException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Optional OpenAI-compatible language service.
///
/// It may point at a local/keyless gateway. Nothing is hard-wired to a vendor:
///   --dart-define=LEARNING_LLM_ENDPOINT=http://192.168.1.10:8000/v1/chat/completions
///   --dart-define=LEARNING_LLM_MODEL=your-model
///   --dart-define=LEARNING_LLM_API_KEY=...  (optional)
class AiLanguageService {
  const AiLanguageService._();

  static const String endpoint = String.fromEnvironment('LEARNING_LLM_ENDPOINT');
  static const String apiKey = String.fromEnvironment('LEARNING_LLM_API_KEY');
  static const String model = String.fromEnvironment('LEARNING_LLM_MODEL', defaultValue: 'gpt-4o-mini');

  static bool get isConfigured => endpoint.trim().isNotEmpty;

  static Future<List<SubtitleCue>> translateCues(
    List<SubtitleCue> cues, {
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (!isConfigured) throw const AiLanguageException('AI translation provider is not configured.');
    if (cues.isEmpty) return const <SubtitleCue>[];
    final translated = <SubtitleCue>[];
    const batchSize = 35;
    for (var offset = 0; offset < cues.length; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, cues.length).toInt();
      final batch = cues.sublist(offset, end);
      final values = batch.map((e) => e.text).toList(growable: false);
      final prompt = '''Translate each subtitle from $sourceLanguage to $targetLanguage.
Return ONLY a JSON array of strings with exactly ${values.length} items, same order.
Preserve names, tone, punctuation, and meaning. Do not merge or split items.
Input JSON:
${jsonEncode(values)}''';
      final content = await _chat(
        system: 'You are a precise audiovisual subtitle translator. Never add commentary.',
        user: prompt,
        temperature: 0.1,
      );
      final decoded = _jsonArrayFromText(content);
      if (decoded.length != batch.length) {
        throw AiLanguageException('Translation provider returned ${decoded.length} items for ${batch.length} subtitles.');
      }
      for (var i = 0; i < batch.length; i++) {
        translated.add(SubtitleCue(start: batch[i].start, end: batch[i].end, text: decoded[i]));
      }
    }
    return translated;
  }

  static Future<String> explainSegment({
    required LearningSegment segment,
    required LearnerProfile profile,
    String? previous,
    String? next,
  }) async {
    if (!isConfigured) throw const AiLanguageException('AI tutor provider is not configured.');
    final context = <String>[
      if (previous != null && previous.trim().isNotEmpty) 'Previous: $previous',
      'Current: ${segment.original}',
      if (segment.translation?.trim().isNotEmpty == true) 'Translation: ${segment.translation}',
      if (next != null && next.trim().isNotEmpty) 'Next: $next',
    ].join('\n');
    return _chat(
      system: 'You are a concise language tutor. Explain the exact dialogue in context. Avoid invented facts.',
      user: '''The learner's native language is ${profile.nativeLanguage}; target language is ${profile.targetLanguage}; CEFR level is ${profile.level}.
$context
Explain the useful vocabulary, natural meaning, grammar only when helpful, connected-speech/listening hints, and give one short new example. Answer primarily in the learner's native language.''',
      temperature: 0.25,
    );
  }

  static Future<String> _chat({
    required String system,
    required String user,
    required double temperature,
  }) async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme) throw const AiLanguageException('LEARNING_LLM_ENDPOINT is invalid.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 60);
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (apiKey.trim().isNotEmpty) request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${apiKey.trim()}');
      request.write(jsonEncode(<String, Object>{
        'model': model,
        'temperature': temperature,
        'messages': <Map<String, String>>[
          <String, String>{'role': 'system', 'content': system},
          <String, String>{'role': 'user', 'content': user},
        ],
      }));
      final response = await request.close().timeout(const Duration(minutes: 2));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiLanguageException(_errorMessage(response.statusCode, body));
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw const AiLanguageException('AI provider returned an unexpected response.');
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw const AiLanguageException('AI provider returned no answer.');
      }
      final message = (choices.first as Map)['message'];
      final content = message is Map ? message['content'] : null;
      if (content is! String || content.trim().isEmpty) throw const AiLanguageException('AI provider returned an empty answer.');
      return content.trim();
    } on SocketException catch (e) {
      throw AiLanguageException('AI provider network error: ${e.message}');
    } on TimeoutException {
      throw const AiLanguageException('AI provider timed out.');
    } on FormatException {
      throw const AiLanguageException('AI provider returned invalid JSON.');
    } finally {
      client.close(force: true);
    }
  }

  static List<String> _jsonArrayFromText(String value) {
    final start = value.indexOf('[');
    final end = value.lastIndexOf(']');
    if (start < 0 || end <= start) throw const AiLanguageException('Translation response did not contain a JSON array.');
    try {
      final decoded = jsonDecode(value.substring(start, end + 1));
      if (decoded is! List) throw const FormatException();
      return decoded.map((e) => e?.toString().trim() ?? '').toList(growable: false);
    } catch (_) {
      throw const AiLanguageException('Translation response contained malformed JSON.');
    }
  }

  static String _errorMessage(int status, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) return 'AI provider failed ($status): ${error['message']}';
        if (decoded['message'] is String) return 'AI provider failed ($status): ${decoded['message']}';
      }
    } catch (_) {}
    return 'AI provider failed ($status).';
  }
}
