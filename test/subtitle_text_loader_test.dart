import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/subtitle_text_loader.dart';

void main() {
  test('remote subtitle streams and decodes valid UTF-8', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType('text', 'vtt');
      request.response.write('WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nHello\n');
      await request.response.close();
    });
    try {
      final value = await SubtitleTextLoader.load(
        'http://${server.address.host}:${server.port}/video.vtt',
      );
      expect(value, contains('WEBVTT'));
      expect(value, contains('Hello'));
    } finally {
      await server.close(force: true);
    }
  });

  test('stalled response headers time out instead of freezing subtitle import', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final release = Completer<void>();
    server.listen((request) async {
      await release.future;
      try {
        request.response.write('too late');
        await request.response.close();
      } catch (_) {}
    });
    try {
      await expectLater(
        SubtitleTextLoader.load(
          'http://${server.address.host}:${server.port}/stalled.vtt',
          networkInactivityTimeout: const Duration(milliseconds: 350),
        ),
        throwsA(isA<SubtitleTextLoaderException>()
            .having((e) => e.message, 'message', contains('stopped responding'))),
      );
    } finally {
      release.complete();
      await server.close(force: true);
    }
  });

  test('mid-stream stall fails even after receiving some bytes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final release = Completer<void>();
    server.listen((request) async {
      request.response.contentLength = 2048;
      request.response.add(const <int>[87, 69, 66, 86, 84, 84]);
      await request.response.flush();
      await release.future;
      try {
        await request.response.close();
      } catch (_) {}
    });
    try {
      await expectLater(
        SubtitleTextLoader.load(
          'http://${server.address.host}:${server.port}/partial.vtt',
          networkInactivityTimeout: const Duration(milliseconds: 350),
        ),
        throwsA(isA<SubtitleTextLoaderException>()
            .having((e) => e.message, 'message', contains('stopped responding'))),
      );
    } finally {
      release.complete();
      await server.close(force: true);
    }
  });

  test('rejects oversized subtitle while streaming without Content-Length', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.bufferOutput = false;
      request.response.add(List<int>.filled(512, 65));
      try {
        await request.response.close();
      } catch (_) {}
    });
    try {
      await expectLater(
        SubtitleTextLoader.load(
          'http://${server.address.host}:${server.port}/huge.srt',
          maxRemoteBytes: 128,
        ),
        throwsA(isA<SubtitleTextLoaderException>()
            .having((e) => e.message, 'message', contains('exceeds'))),
      );
    } finally {
      await server.close(force: true);
    }
  });

  test('rejects advertised oversized subtitle without reading body', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final release = Completer<void>();
    server.listen((request) async {
      request.response.contentLength = 2048;
      // Flush a real byte so dart:io sends the Content-Length headers before
      // the test deliberately pauses the body. flush() with no bytes may
      // defer header transmission until after the server is released.
      request.response.add(const <int>[65]);
      await request.response.flush();
      await release.future;
      try {
        await request.response.close();
      } catch (_) {}
    });
    try {
      await expectLater(
        SubtitleTextLoader.load(
          'http://${server.address.host}:${server.port}/huge2.srt',
          maxRemoteBytes: 128,
        ),
        throwsA(isA<SubtitleTextLoaderException>()
            .having((e) => e.message, 'message', contains('exceeds'))),
      );
    } finally {
      release.complete();
      await server.close(force: true);
    }
  });
}
