import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class SubtitleTextLoader {
  const SubtitleTextLoader._();
  static const MethodChannel _channel = MethodChannel('elnemr/files');

  static Future<String> load(String source) async {
    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final client = HttpClient();
      try {
        final response = await (await client.getUrl(uri)).close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('Subtitle HTTP ${response.statusCode}', uri: uri);
        }
        return utf8.decode(await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b)), allowMalformed: true);
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
    final text = await _channel.invokeMethod<String>('readTextFile', <String, Object?>{'uri': source});
    if (text == null) throw FileSystemException('Could not read subtitle', source);
    return text;
  }
}
