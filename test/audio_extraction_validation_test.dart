import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:el_nemr_language/learning/services/audio_extraction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('elnemr/audio_extractor');
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('elnemr_wav_check_');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Uint8List sampleWav({int sampleRate = 16000, int channels = 1}) {
    const dataSize = 320;
    final bytes = Uint8List(44 + dataSize);
    final data = ByteData.sublistView(bytes);
    void chunk(int at, String value) {
      for (var i = 0; i < 4; i++) {
        bytes[at + i] = value.codeUnitAt(i);
      }
    }
    chunk(0, 'RIFF');
    data.setUint32(4, 36 + dataSize, Endian.little);
    chunk(8, 'WAVE');
    chunk(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * channels * 2, Endian.little);
    data.setUint16(32, channels * 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    chunk(36, 'data');
    data.setUint32(40, dataSize, Endian.little);
    return bytes;
  }

  test('accepts a valid native 16 kHz mono PCM WAV', () async {
    final output = File('${temp.path}/accepted.wav');
    await output.writeAsBytes(sampleWav());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => output.path);

    final result = await AudioExtractionService.extractToWav('/tmp/example.mp4');
    expect(result, output.path);
    expect(await output.exists(), isTrue);
  });

  test('rejects corrupt sample rate and cleans invalid WAV', () async {
    final output = File('${temp.path}/invalid.wav');
    await output.writeAsBytes(sampleWav(sampleRate: 8000));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => output.path);

    await expectLater(
      AudioExtractionService.extractToWav('/tmp/example.mp4'),
      throwsA(isA<AudioExtractionException>()),
    );
    expect(await output.exists(), isFalse);
  });

  test('rejects missing native output', () async {
    final output = File('${temp.path}/not_created.wav');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => output.path);

    await expectLater(
      AudioExtractionService.extractToWav('/tmp/example.mp4'),
      throwsA(isA<AudioExtractionException>()),
    );
  });
}
