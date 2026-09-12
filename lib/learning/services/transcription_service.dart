import 'dart:io';

import 'package:whisper_kit/whisper_kit.dart';

import '../models/subtitle_cue.dart';
import 'audio_extraction_service.dart';
import 'offline_speech_model_service.dart';
import 'text_language_detector.dart';

class TranscriptionResult {
  const TranscriptionResult({required this.cues, this.language});
  final List<SubtitleCue> cues;
  final String? language;
}

class TranscriptionException implements Exception {
  const TranscriptionException(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef TranscriptionProgress = void Function(double progress, String stage);

/// Fully local video transcription.
///
/// The media audio track is first decoded by the native platform into a
/// Whisper-compatible 16 kHz PCM WAV file. `whisper_kit` then performs ASR on
/// the device. The model is downloaded once on first use and reused offline.
class TranscriptionService {
  const TranscriptionService._();

  static bool get isConfigured => true;

  static WhisperModel get _model => switch (
        const String.fromEnvironment('LEARNING_WHISPER_MODEL', defaultValue: 'base').toLowerCase()
      ) {
        'tiny' => WhisperModel.tiny,
        'small' => WhisperModel.small,
        'medium' => WhisperModel.medium,
        _ => WhisperModel.base,
      };

  static Future<TranscriptionResult> transcribe(
    String source, {
    String? languageHint,
    Map<String, String> httpHeaders = const {},
    bool allowSelfSigned = false,
    TranscriptionProgress? onProgress,
  }) async {
    String? wavPath;
    try {
      onProgress?.call(0.03, 'Extracting audio locally');
      wavPath = await AudioExtractionService.extractToWav(
        source,
        preferredLanguage: languageHint,
        httpHeaders: httpHeaders,
        allowSelfSigned: allowSelfSigned,
      );
      onProgress?.call(0.15, 'Preparing offline speech model');
      await OfflineSpeechModelService.ensureDownloaded(
        onProgress: (fraction) {
          onProgress?.call(
            0.15 + fraction * 0.25,
            'Downloading speech model · ${(fraction * 100).round()}%',
          );
        },
      );
      final modelDir = await OfflineSpeechModelService.modelDirectory();
      final whisper = Whisper(
        model: _model,
        modelDir: modelDir.path,
      );

      onProgress?.call(0.42, 'Transcribing on this device');
      final response = await whisper.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: wavPath,
          language: (languageHint == null || languageHint.trim().isEmpty) ? 'auto' : languageHint.trim().toLowerCase(),
          isTranslate: false,
          isNoTimestamps: false,
          splitOnWord: false,
          // The extracted learning WAV is mono. Standard whisper.cpp stereo
          // diarization would be meaningless here; role-play speaker labels
          // come from subtitle/VTT speaker metadata when available.
          diarize: false,
        ),
      );

      final cues = <SubtitleCue>[];
      for (final segment in response.segments ?? const []) {
        final text = segment.text.trim();
        if (text.isEmpty || segment.toTs <= segment.fromTs) continue;
        cues.add(SubtitleCue(start: segment.fromTs, end: segment.toTs, text: text));
      }
      cues.sort((a, b) => a.start.compareTo(b.start));
      if (cues.isEmpty) {
        throw const TranscriptionException('No timed speech was detected in this video.');
      }

      final detectedLanguage = languageHint?.trim().isNotEmpty == true
          ? languageHint!.trim().toLowerCase()
          : TextLanguageDetector.detect(cues.take(80).map((e) => e.text).join(' '));
      onProgress?.call(1, 'Transcript ready');
      return TranscriptionResult(
        cues: cues,
        language: detectedLanguage.isEmpty ? null : detectedLanguage,
      );
    } on AudioExtractionException catch (e) {
      throw TranscriptionException(e.message);
    } on WhisperKitException catch (e) {
      throw TranscriptionException('Offline transcription failed: $e');
    } catch (e) {
      if (e is TranscriptionException) rethrow;
      throw TranscriptionException('Offline transcription failed: $e');
    } finally {
      if (wavPath != null) {
        try { await File(wavPath).delete(); } catch (_) {}
      }
    }
  }

  static String toSrt(List<SubtitleCue> cues) {
    final buffer = StringBuffer();
    for (var i = 0; i < cues.length; i++) {
      final cue = cues[i];
      buffer
        ..writeln(i + 1)
        ..writeln('${_srtTime(cue.start)} --> ${_srtTime(cue.end)}')
        ..writeln(cue.text.trim())
        ..writeln();
    }
    return buffer.toString();
  }

  static String _srtTime(Duration d) {
    final totalMs = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
    final h = totalMs ~/ 3600000;
    final m = (totalMs ~/ 60000) % 60;
    final s = (totalMs ~/ 1000) % 60;
    final ms = totalMs % 1000;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')},${ms.toString().padLeft(3, '0')}';
  }
}
