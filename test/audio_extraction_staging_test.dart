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
}
