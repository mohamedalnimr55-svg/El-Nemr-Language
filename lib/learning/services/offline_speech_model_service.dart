import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_kit/download_model.dart' show downloadModel;
import 'package:whisper_kit/whisper_kit.dart';

class OfflineSpeechModelStatus {
  const OfflineSpeechModelStatus({
    required this.ready,
    required this.modelLabel,
    this.modelPath,
  });

  final bool ready;
  final String modelLabel;
  final String? modelPath;
}

/// Owns the on-device Whisper model lifecycle so the app can explicitly show
/// first-use download/readiness instead of surprising the learner during play.
class OfflineSpeechModelService {
  const OfflineSpeechModelService._();

  static const _savedPathKey = 'learning.whisper.modelPath';
  static const _savedModelKey = 'learning.whisper.model';

  static WhisperModel get configuredModel => switch (
        const String.fromEnvironment(
          'LEARNING_WHISPER_MODEL',
          defaultValue: 'base',
        ).toLowerCase()
      ) {
        'tiny' => WhisperModel.tiny,
        'small' => WhisperModel.small,
        'medium' => WhisperModel.medium,
        _ => WhisperModel.base,
      };

  static String get _modelSlug => switch (configuredModel) {
        WhisperModel.tiny => 'tiny',
        WhisperModel.small => 'small',
        WhisperModel.medium => 'medium',
        _ => 'base',
      };

  static String get modelLabel => switch (configuredModel) {
        WhisperModel.tiny => 'Tiny · ~75 MB',
        WhisperModel.small => 'Small · ~466 MB',
        WhisperModel.medium => 'Medium · ~1.5 GB',
        _ => 'Base · ~142 MB',
      };

  static Future<Directory> modelDirectory() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}whisper_models');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<OfflineSpeechModelStatus> status() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_savedPathKey);
    final savedModel = prefs.getString(_savedModelKey);
    if (savedModel == _modelSlug && saved != null && saved.isNotEmpty) {
      final file = File(saved);
      if (await file.exists() && await file.length() > 1024 * 1024) {
        return OfflineSpeechModelStatus(
          ready: true,
          modelLabel: modelLabel,
          modelPath: file.path,
        );
      }
    }

    // whisper.cpp models downloaded by whisper_kit use ggml-<model>.bin.
    // Only accept the currently configured model; an old Base model must not
    // make a later Small/Medium configuration appear ready.
    final dir = await modelDirectory();
    final expectedName = 'ggml-$_modelSlug.bin';
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      if (entry.uri.pathSegments.last.toLowerCase() != expectedName) continue;
      if (await entry.length() <= 1024 * 1024) continue;
      await prefs.setString(_savedPathKey, entry.path);
      await prefs.setString(_savedModelKey, _modelSlug);
      return OfflineSpeechModelStatus(
        ready: true,
        modelLabel: modelLabel,
        modelPath: entry.path,
      );
    }

    return OfflineSpeechModelStatus(ready: false, modelLabel: modelLabel);
  }

  static Future<String> ensureDownloaded({
    void Function(double progress)? onProgress,
  }) async {
    final existing = await status();
    if (existing.ready && existing.modelPath != null) return existing.modelPath!;

    final dir = await modelDirectory();
    final downloaded = await downloadModel(
      model: configuredModel,
      destinationPath: dir.path,
      onDownloadProgress: (received, total) {
        if (total <= 0) {
          onProgress?.call(0);
          return;
        }
        onProgress?.call((received / total).clamp(0.0, 1.0).toDouble());
      },
    );

    final resolved = File(downloaded);
    if (!await resolved.exists()) {
      throw const FileSystemException('Whisper model download completed but the model file was not found.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedPathKey, resolved.path);
    await prefs.setString(_savedModelKey, _modelSlug);
    onProgress?.call(1);
    return resolved.path;
  }
}
