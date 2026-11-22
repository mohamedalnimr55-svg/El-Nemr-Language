import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/audio_extraction_service.dart';

void main() {
  test('protected HTTP media is staged with headers and cleaned up', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var sawAuthorization = false;
    server.listen((request) async {
      sawAuthorization = request.headers.value(HttpHeaders.authorizationHeader) == 'Bearer rc3-test';
      request.response
        ..statusCode = HttpStatus.ok
        ..add(const <int>[1, 2, 3, 4, 5, 6]);
      await request.response.close();
    });

    PreparedAudioSource? prepared;
    try {
      prepared = await AudioExtractionService.prepareSource(
        'http://${server.address.host}:${server.port}/movie.mkv',
        httpHeaders: const {HttpHeaders.authorizationHeader: 'Bearer rc3-test'},
      );
      expect(sawAuthorization, isTrue);
      expect(prepared.source, isNot(contains('http://')));
      final staged = File(prepared.source);
      expect(await staged.exists(), isTrue);
      expect(await staged.readAsBytes(), const <int>[1, 2, 3, 4, 5, 6]);

      final stagedPath = prepared.source;
      await prepared.dispose();
      prepared = null;
      expect(await File(stagedPath).exists(), isFalse);
    } finally {
      await prepared?.dispose();
      await server.close(force: true);
    }
  });

  test('local sources are passed through without staging', () async {
    final prepared = await AudioExtractionService.prepareSource('/tmp/example.mp4');
    expect(prepared.source, '/tmp/example.mp4');
    await prepared.dispose();
  });
  test('protected media fails instead of hanging when server never sends headers',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final release = Completer<void>();
    server.listen((request) async {
      await release.future;
      try {
        request.response.write('late');
        await request.response.close();
      } catch (_) {}
    });
    try {
      await expectLater(
        AudioExtractionService.prepareSource(
          'http://${server.address.host}:${server.port}/stalled.mkv',
          networkInactivityTimeout: const Duration(milliseconds: 300),
        ),
        throwsA(isA<AudioExtractionException>()
            .having((e) => e.message, 'message', contains('stopped responding'))),
      );
    } finally {
      release.complete();
      await server.close(force: true);
    }
  });

  test('protected media fails if transfer stops after initial bytes',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final release = Completer<void>();
    server.listen((request) async {
      request.response.contentLength = 1024;
      request.response.add(const <int>[1, 2, 3, 4]);
      await request.response.flush();
      await release.future;
      try {
        await request.response.close();
      } catch (_) {}
    });
    try {
      await expectLater(
        AudioExtractionService.prepareSource(
          'http://${server.address.host}:${server.port}/partial.mkv',
          networkInactivityTimeout: const Duration(milliseconds: 300),
        ),
        throwsA(isA<AudioExtractionException>()
            .having((e) => e.message, 'message', contains('stopped responding'))),
      );
    } finally {
      release.complete();
      await server.close(force: true);
    }
  });

}
