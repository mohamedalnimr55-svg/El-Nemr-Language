import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../models/learner_profile.dart';
import '../services/learner_profile_store.dart';
import '../services/offline_speech_model_service.dart';
import '../services/on_device_translation_service.dart';

class OfflineAiSetupScreen extends StatefulWidget {
  const OfflineAiSetupScreen({super.key});

  @override
  State<OfflineAiSetupScreen> createState() => _OfflineAiSetupScreenState();
}

class _OfflineAiSetupScreenState extends State<OfflineAiSetupScreen> {
  LearnerProfile? _profile;
  OfflineSpeechModelStatus? _speech;
  bool _translationReady = false;
  bool _loading = true;
  bool _preparing = false;
  double _speechProgress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final profile = await LearnerProfileStore.load();
      final speech = await OfflineSpeechModelService.status();
      final translationReady = await _translationModelsReady(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _speech = speech;
        _translationReady = translationReady;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<bool> _translationModelsReady(LearnerProfile profile) async {
    final source = OnDeviceTranslationService.languageFor(profile.targetLanguage);
    final target = OnDeviceTranslationService.languageFor(profile.nativeLanguage);
    if (source == null || target == null || source == target) return true;
    final manager = OnDeviceTranslatorModelManager();
    return await manager.isModelDownloaded(source.bcpCode) &&
        await manager.isModelDownloaded(target.bcpCode);
  }

  Future<void> _prepare() async {
    if (_preparing) return;
    setState(() {
      _preparing = true;
      _speechProgress = 0;
      _error = null;
    });
    try {
      await OfflineSpeechModelService.ensureDownloaded(
        onProgress: (value) {
          if (mounted) setState(() => _speechProgress = value);
        },
      );
      final profile = _profile ?? await LearnerProfileStore.load();
      if (OnDeviceTranslationService.canTranslate(
        profile.targetLanguage,
        profile.nativeLanguage,
      )) {
        await OnDeviceTranslationService.ensureModels(
          sourceLanguage: profile.targetLanguage,
          targetLanguage: profile.nativeLanguage,
        );
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline AI readiness')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Core learning works without API keys',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Internet is needed once to download the speech and translation models. After that, video transcription and the prepared language pair can work on-device.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: Icon(
                    _speech?.ready == true ? Icons.check_circle_rounded : Icons.download_for_offline_rounded,
                    color: _speech?.ready == true ? Colors.greenAccent : Colors.lightBlueAccent,
                  ),
                  title: const Text('Speech-to-text model'),
                  subtitle: Text(
                    _speech?.ready == true
                        ? '${_speech!.modelLabel} · ready offline'
                        : '${_speech?.modelLabel ?? OfflineSpeechModelService.modelLabel} · download once',
                  ),
                ),
                ListTile(
                  leading: Icon(
                    _translationReady ? Icons.check_circle_rounded : Icons.translate_rounded,
                    color: _translationReady ? Colors.greenAccent : Colors.amberAccent,
                  ),
                  title: const Text('Learning translation models'),
                  subtitle: Text(
                    profile == null
                        ? 'Profile unavailable'
                        : _translationReady
                            ? '${profile.targetLanguage.toUpperCase()} ↔ ${profile.nativeLanguage.toUpperCase()} · ready offline'
                            : '${profile.targetLanguage.toUpperCase()} ↔ ${profile.nativeLanguage.toUpperCase()} · download once',
                  ),
                ),
                if (_preparing) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: _speechProgress > 0 && _speechProgress < 1 ? _speechProgress : null),
                  const SizedBox(height: 8),
                  Text(
                    _speechProgress < 1 ? 'Preparing speech model…' : 'Preparing translation models…',
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _preparing || (_speech?.ready == true && _translationReady) ? null : _prepare,
                  icon: const Icon(Icons.offline_bolt_rounded),
                  label: Text(
                    _speech?.ready == true && _translationReady
                        ? 'Offline learning is ready'
                        : 'Prepare offline learning',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'If you later watch a video in a third language, El-Nemr Language may download that language model the first time it needs to translate it.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
    );
  }
}
