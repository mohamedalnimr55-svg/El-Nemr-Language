import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../models/learner_profile.dart';
import '../services/learner_profile_store.dart';
import '../services/ai_language_service.dart';
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
  final TextEditingController _aiEndpointController = TextEditingController();
  final TextEditingController _aiModelController = TextEditingController();
  bool _aiChecking = false;
  String? _aiStatus;

  @override
  void dispose() {
    _aiEndpointController.dispose();
    _aiModelController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await AiLanguageService.loadConfiguration();
      final profile = await LearnerProfileStore.load();
      final speech = await OfflineSpeechModelService.status();
      final translationReady = await _translationModelsReady(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _aiEndpointController.text = AiLanguageService.endpoint;
        _aiModelController.text = AiLanguageService.model;
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
    // An unsupported language pair must never be reported as downloaded.
    if (source == null || target == null) return false;
    if (source == target) return true;
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

  Future<void> _saveAndTestAi() async {
    if (_aiChecking) return;
    setState(() {
      _aiChecking = true;
      _aiStatus = null;
    });
    try {
      await AiLanguageService.setModel(_aiModelController.text);
      await AiLanguageService.setEndpoint(_aiEndpointController.text);
      if (!AiLanguageService.isConfigured) {
        if (mounted) setState(() => _aiStatus = 'No AI provider configured. The local rule-based coach remains available.');
        return;
      }
      await AiLanguageService.testConnection();
      if (mounted) setState(() => _aiStatus = 'AI provider answered a real test request successfully.');
    } catch (e) {
      if (mounted) setState(() => _aiStatus = 'AI provider is not ready: $e');
    } finally {
      if (mounted) setState(() => _aiChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final translationUnavailable = profile != null &&
        (OnDeviceTranslationService.languageFor(profile.targetLanguage) == null ||
         OnDeviceTranslationService.languageFor(profile.nativeLanguage) == null);
    final offlineReady = _speech?.ready == true && (_translationReady || translationUnavailable);
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
                    translationUnavailable ? Icons.warning_amber_rounded : (_translationReady ? Icons.check_circle_rounded : Icons.translate_rounded),
                    color: translationUnavailable ? Colors.orangeAccent : (_translationReady ? Colors.greenAccent : Colors.amberAccent),
                  ),
                  title: const Text('Learning translation models'),
                  subtitle: Text(
                    profile == null
                        ? 'Profile unavailable'
                        : translationUnavailable
                            ? '${profile.targetLanguage.toUpperCase()} ↔ ${profile.nativeLanguage.toUpperCase()} · unsupported on-device'
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
                  onPressed: _preparing || offlineReady ? null : _prepare,
                  icon: const Icon(Icons.offline_bolt_rounded),
                  label: Text(
                    offlineReady
                        ? (translationUnavailable ? 'Speech ready · translation unavailable' : 'Offline learning is ready')
                        : 'Prepare offline learning',
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Optional AI Tutor connection', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter an OpenAI-compatible /v1/chat/completions endpoint. '
                          'Without a working server, only the local rule-based coach is available. '
                          'Use HTTPS for remote gateways; never include an API key in the URL. '
                          'This setting is for a trusted gateway that does not require a client-side API key.',
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _aiEndpointController,
                          enabled: !_aiChecking,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'AI Tutor gateway URL',
                            hintText: 'https://your-gateway.example/v1/chat/completions',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _aiModelController,
                          enabled: !_aiChecking,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'Gateway model identifier',
                            hintText: 'Your actual model name, e.g. llama3.2',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _aiChecking ? null : _saveAndTestAi,
                          icon: _aiChecking
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.network_check),
                          label: const Text('Save and test connection'),
                        ),
                        if (_aiStatus != null) ...[
                          const SizedBox(height: 8),
                          Text(_aiStatus!),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (translationUnavailable)
                  const Text(
                    'This language pair is not supported by the installed on-device translation engine.',
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
                const Text(
                  'If you later watch a video in a third language, El-Nemr Language may download that language model the first time it needs to translate it.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
    );
  }
}
