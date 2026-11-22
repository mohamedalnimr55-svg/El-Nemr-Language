import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
    Duration networkInactivityTimeout = const Duration(seconds: 30),
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
      // A server can accept TCP but never send headers, or start streaming
      // media and then stall indefinitely. Limit *inactivity* per stage,
      // without imposing a total timeout on long legitimate videos.
      final request = await client.getUrl(uri).timeout(networkInactivityTimeout);
      httpHeaders.forEach(request.headers.set);
      final response = await request.close().timeout(networkInactivityTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AudioExtractionException(
          'Could not prepare protected media for offline transcription '
          '(HTTP ${response.statusCode}).',
        );
      }
      final sink = stagedFile.openWrite();
      try {
        // Stream.pipe() closes its sink on completion/error. Closing the same
        // IOSink again in a finally block masks the original TimeoutException
        // with FileSystemException("File closed"). Explicit streaming lets us
        // preserve the network timeout and reliably clean up partial files.
        await for (final chunk in response.timeout(networkInactivityTimeout)) {
          sink.add(chunk);
        }
        await sink.flush();
      } finally {
        try {
          await sink.close();
        } catch (_) {
          // Never replace the original network/storage failure with a
          // secondary error while closing the partial temporary file.
        }
      }
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
      if (e is TimeoutException) {
        throw const AudioExtractionException(
          'Media download stopped responding. Check the connection or retry transcription.',
        );
      }
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
      // Fail early on malformed native output instead of giving Whisper
      // a nonexistent/empty/mistyped WAV and reporting an opaque ASR error.
      try {
        await _validateNativeWav(path);
      } catch (_) {
        try {
          final invalidFile = File(path);
          if (await invalidFile.exists()) await invalidFile.delete();
        } catch (_) {}
        rethrow;
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

  static Future<void> _validateNativeWav(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const AudioExtractionException('Native audio extractor returned a missing WAV file.');
    }
    final fileLength = await file.length();
    if (fileLength <= 44) {
      throw const AudioExtractionException('Native audio extractor returned an empty or truncated WAV file.');
    }

    final handle = await file.open(mode: FileMode.read);
    late Uint8List header;
    try {
      header = await handle.read(44);
    } finally {
      await handle.close();
    }
    if (header.length != 44) {
      throw const AudioExtractionException('Could not read the WAV audio header.');
    }

    final bytes = ByteData.sublistView(header);
    bool matches(int offset, List<int> letters) {
      for (var i = 0; i < letters.length; i++) {
        if (header[offset + i] != letters[i]) return false;
      }
      return true;
    }

    const riff = <int>[82, 73, 70, 70];
    const wave = <int>[87, 65, 86, 69];
    const fmt = <int>[102, 109, 116, 32];
    const data = <int>[100, 97, 116, 97];
    final isCorrectFormat =
        matches(0, riff) &&
        matches(8, wave) &&
        matches(12, fmt) &&
        bytes.getUint32(16, Endian.little) == 16 &&
        bytes.getUint16(20, Endian.little) == 1 &&
        bytes.getUint16(22, Endian.little) == 1 &&
        bytes.getUint32(24, Endian.little) == 16000 &&
        bytes.getUint32(28, Endian.little) == 32000 &&
        bytes.getUint16(32, Endian.little) == 2 &&
        bytes.getUint16(34, Endian.little) == 16 &&
        matches(36, data);
    final declaredData = bytes.getUint32(40, Endian.little);
    if (!isCorrectFormat ||
        declaredData == 0 ||
        declaredData.isOdd ||
        declaredData > fileLength - 44 ||
        bytes.getUint32(4, Endian.little) + 8 > fileLength) {
      throw const AudioExtractionException(
        'Native audio extractor returned invalid 16-kHz mono PCM WAV audio.',
      );
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
