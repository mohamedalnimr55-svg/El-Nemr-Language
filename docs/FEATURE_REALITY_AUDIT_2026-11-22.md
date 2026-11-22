# El-Nemr Language — function-level reality audit (2026-11-22)

Scope: GitHub branch `full-native-build` at `a3b5da7c982a8994743193b4d19da37d66406558`. This is a **source inspection**, not a successful Android device acceptance test.

## Evidence found

| Function | Source evidence | Reality / gate |
| --- | --- | --- |
| AI Tutor | `AiLanguageService` sends OpenAI-compatible chat requests only if `LEARNING_LLM_ENDPOINT` is configured. `LocalLanguageCoach` returns prewritten translations/hints otherwise. | Provider is **unconfigured in ordinary builds**. The existing `learning_ai_service_test.dart` merely asserted that it was unconfigured. This branch adds editable endpoint configuration and a real test request; acceptance still requires a working gateway. |
| Offline transcription | `AudioExtractionService` invokes `elnemr/audio_extractor`; `AudioExtractor.kt` uses MediaExtractor/MediaCodec to create 16-kHz PCM WAV; `TranscriptionService` calls `whisper_kit`. | Real implementation paths are present, but the existing `learning_transcription_test.dart` covers SRT formatting, not WAV extraction/ASR on representative videos. **Not device-verified.** |
| On-device translation | `OnDeviceTranslationService` invokes Google ML Kit model manager and translator. | A missing/unsupported language pair was considered 'ready' by `OfflineAiSetupScreen`. Corrected in this branch; still needs model download + translation hardware test. |
| Speaking / shadowing | Native `SpeechCoach` bridge, `SpeechCoachService`, `LearningEngine`, `SpeechAssessment`. | Speech scoring is word-transcript alignment and rough duration ratio, **not phoneme-level pronunciation**. Needs recording/recognizer and microphone permission tests on real devices. |
| Automated audit | `scripts/feature_wiring_audit.py` mostly tests regexes for presence of names. | Regex presence cannot prove channels, models, or networking actually run. **Do not report these regex checks as feature completion.** |

## Acceptance gates (none should be marked passed without evidence)

- [ ] Flutter dependency resolution, analysis, and unit/widget tests on exact PR commit.
- [ ] Signed Android APK builds from PR commit; identify actual SHA.
- [ ] Play MP4 and MKV, open subtitle overlays, seek/pause/repeat on Android device.
- [ ] Extract audio from MP4, MKV and one protected source, confirm complete nonempty 16-kHz mono WAV, no file leaks.
- [ ] First-use Whisper download, restart persistence, offline transcript of a known 30-second sample with timestamp sanity checks.
- [ ] ML Kit first-use model download; translate 10 sample cues, preserve cue count/timings and handle unsupported pair accurately.
- [ ] AI Tutor: save a gateway URL, restart app, issue successful chat request, and verify an unreachable gateway produces a clear error.
- [ ] Speech: grant/deny microphone, listen and stop; verify recognized words, not a phoneme or accent score.
- [ ] Run end-to-end learning journey on actual device: select video → transcript → translate → replay → answer → save word → review.

## Implementation principles

- A source file is **implemented**, not automatically **working**.
- An automated test may be **passed** without proving hardware behavior.
- Missing gateways, unsupported languages, and unavailable models must show honest states instead of success badges.
- Keep `full-native-build` unchanged until PR validation and device acceptance.
