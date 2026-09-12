import 'dart:io';

import 'package:flutter/services.dart';

class AudioExtractionException implements Exception {
  const AudioExtractionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PreparedAudioSource {
  PreparedAudioSource(this.source, [this._tempDirectory]);

  final String source;
  final Directory? _tempDirectory;

  Future<void> dispose() async {
    final dir = _tempDirectory;
    if (dir == null) return;
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}

class AudioExtractionService {
  const AudioExtractionService._();

  static const MethodChannel _channel = MethodChannel('elnemr/audio_extractor');

  /// For authenticated HTTP(S)/WebDAV sources, stage a temporary local copy
  /// with the same headers used by playback. This avoids relying on private or
  /// unsupported native media-framework header injection APIs.
  static Future<PreparedAudioSource> prepareSource(
    String source, {
    Map<String, String> httpHeaders = const {},
    bool allowSelfSigned = false,
  }) async {
    final uri = Uri.tryParse(source);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return PreparedAudioSource(source);
    }

    final tempDir = await Directory.systemTemp.createTemp('elnemr_audio_stage_');
    final ext = _safeExtension(uri.path);
    final stagedFile = File('${tempDir.path}/source$ext');
    final client = HttpClient();
    if (allowSelfSigned) {
      client.badCertificateCallback =
          (X509Certificate _, String __, int ___) => true;
    }

    try {
      final request = await client.getUrl(uri);
      httpHeaders.forEach(request.headers.set);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AudioExtractionException(
          'Could not prepare protected media for offline transcription '
          '(HTTP ${response.statusCode}).',
        );
      }
      final sink = stagedFile.openWrite();
      await response.pipe(sink);
      if (!await stagedFile.exists() || await stagedFile.length() == 0) {
        throw const AudioExtractionException(
          'Protected media staging produced an empty file.',
        );
      }
      return PreparedAudioSource(stagedFile.path, tempDir);
    } catch (e) {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      } catch (_) {}
      if (e is AudioExtractionException) rethrow;
      throw AudioExtractionException('Could not prepare media for offline transcription: $e');
    } finally {
      client.close(force: true);
    }
  }

  /// Extracts the selected/first audio track to a Whisper-compatible
  /// 16 kHz, 16-bit PCM mono WAV file in the app cache directory.
  static Future<String> extractToWav(
    String source, {
    String? preferredLanguage,
    Map<String, String> httpHeaders = const {},
    bool allowSelfSigned = false,
  }) async {
    final prepared = await prepareSource(
      source,
      httpHeaders: httpHeaders,
      allowSelfSigned: allowSelfSigned,
    );
    try {
      final path = await _channel.invokeMethod<String>(
        'extractToWav',
        <String, Object?>{
          'source': prepared.source,
          'preferredLanguage': preferredLanguage,
        },
      );
      if (path == null || path.trim().isEmpty) {
        throw const AudioExtractionException(
          'Audio extraction returned no output file.',
        );
      }
      return path;
    } on PlatformException catch (e) {
      throw AudioExtractionException(
        e.message ?? 'Audio extraction failed (${e.code}).',
      );
    } finally {
      await prepared.dispose();
    }
  }

  static String _safeExtension(String path) {
    final slash = path.lastIndexOf('/');
    final dot = path.lastIndexOf('.');
    if (dot <= slash || dot < 0) return '.media';
    final value = path.substring(dot);
    if (!RegExp(r'^\.[A-Za-z0-9]{1,8}$').hasMatch(value)) return '.media';
    return value.toLowerCase();
  }
}
