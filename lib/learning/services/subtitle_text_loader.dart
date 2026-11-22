import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class SubtitleTextLoaderException implements Exception {
  const SubtitleTextLoaderException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SubtitleTextLoader {
  const SubtitleTextLoader._();
  static const MethodChannel _channel = MethodChannel('elnemr/files');
  static const int defaultMaxRemoteBytes = 8 * 1024 * 1024;

  /// Bound remote subtitle downloads. For slow but active connections, the
  /// transfer may continue; timeout is reset whenever data arrives.
  /// Only HTTP(S) uses these limits. Local/SAF content is read normally.
  static Future<String> load(
    String source, {
    Duration networkInactivityTimeout = const Duration(seconds: 25),
    int maxRemoteBytes = defaultMaxRemoteBytes,
  }) async {
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      if (maxRemoteBytes <= 0) {
        throw const ArgumentError('maxRemoteBytes must be positive');
      }
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri).timeout(networkInactivityTimeout);
        final response = await request.close().timeout(networkInactivityTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw SubtitleTextLoaderException(
            'Subtitle download failed (HTTP ${response.statusCode}).',
          );
        }
        if (response.contentLength > maxRemoteBytes) {
          throw SubtitleTextLoaderException(
            'Subtitle file exceeds the ${maxRemoteBytes ~/ 1024} KB limit.',
          );
        }
        final bytes = BytesBuilder(copy: false);
        var received = 0;
        await for (final chunk in response.timeout(networkInactivityTimeout)) {
          received += chunk.length;
          if (received > maxRemoteBytes) {
            throw SubtitleTextLoaderException(
              'Subtitle file exceeds the ${maxRemoteBytes ~/ 1024} KB limit.',
            );
          }
          bytes.add(chunk);
        }
        return utf8.decode(bytes.takeBytes(), allowMalformed: true);
      } on TimeoutException {
        throw const SubtitleTextLoaderException(
          'Subtitle download stopped responding. Check your network and retry.',
        );
      } on SocketException {
        throw const SubtitleTextLoaderException(
          'Could not connect to the subtitle server. Check your network.',
        );
      } finally {
        client.close(force: true);
      }
    }
    if (uri != null && uri.scheme == 'file') {
      return File(uri.toFilePath()).readAsString();
    }
    if (uri == null || uri.scheme.isEmpty) {
      return File(source).readAsString();
    }
    final text = await _channel.invokeMethod<String>(
      'readTextFile',
      <String, Object?>{'uri': source},
    );
    if (text == null) throw FileSystemException('Could not read subtitle', source);
    return text;
  }
}
