# El-Nemr Language Learning Edition 0.8.0 — Build & Release

## Supported baseline

- Android: minSdk 26 (Android 8.0); Android 10+ recommended.
- iOS: 17.0, matching this source tree.
- Flutter/Dart: use a Flutter release compatible with Dart `^3.12.2` from `pubspec.yaml`.

## First build

```bash
flutter clean
flutter pub get
./scripts/verify_learning_edition.sh
```

The verification script formats/analyzes the learning code, runs focused learning tests and builds a debug APK. On macOS it also regenerates the iOS Flutter Swift-Package configuration.

## Discover providers (no key required)

The Discover and Search tabs use Internet Archive and Wikimedia Commons public APIs. No account, API key, or subscription is required. Network access is required to browse; once a direct HTTP video is open, the existing player/download paths apply normally.

## Optional providers

The player and manually-added learning subtitles work without any external AI provider.

OpenSubtitles search:

```bash
--dart-define=OPENSUBTITLES_API_KEY=...
```

Timed ASR (OpenAI-compatible transcription endpoint):

```bash
--dart-define=LEARNING_ASR_ENDPOINT=https://host/v1/audio/transcriptions
--dart-define=LEARNING_ASR_MODEL=whisper-1
--dart-define=LEARNING_ASR_API_KEY=OPTIONAL
```

AI Tutor / fallback translation (OpenAI-compatible chat endpoint):

```bash
--dart-define=LEARNING_LLM_ENDPOINT=https://host/v1/chat/completions
--dart-define=LEARNING_LLM_MODEL=model-name
--dart-define=LEARNING_LLM_API_KEY=OPTIONAL
```

## Free translation path

When a native-language subtitle cannot be found, the app attempts Google ML Kit on-device translation before an optional AI endpoint. Supported language models are downloaded on first use; no API key is required for this local translation path.

## Release gates

Before shipping a signed binary, verify on real devices:

1. Local MP4/MKV playback and seek on Android Media3 and libmpv fallback.
2. iOS Aether/AVPlayer playback.
3. Two, three and four simultaneous text subtitle layers.
4. Drag/pinch/lock and persistence after app restart.
5. Auto Prepare with: existing subtitle, OpenSubtitles hit, ASR fallback, local translation fallback.
6. Airplane-mode use after ML Kit language models have already been downloaded.
7. Arabic RTL and English/German LTR subtitle rendering.
8. Long videos (90–180 min), overlapping subtitle cues and ±10 s subtitle delay.
9. Learning Studio while playback continues behind the sheet.
10. Listening/Shadow microphone permissions, cancellation and denied-permission paths.
11. Smart Coach speed restoration after a difficult segment.
12. Role Play, video flashcard save/review and due-card persistence.
13. Rotation, background/resume, Bluetooth audio and wired headset controls.
14. Low-memory device behavior and model-download failure handling.
15. Discover target-language ranking, global search, category filters and progressive row loading.
16. Japanese-vs-Korean (or equivalent) mismatch warning: Play anyway must never mutate the learner profile.
17. Internet Archive open-license item playback + sidecar subtitle import, and Wikimedia Commons direct video playback.
18. Provider outage/timeout behavior, pull-to-refresh cache bypass, and explicit-adult result filtering.
19. Five-tab navigation on small phones: Home / Discover / Search / Local / Profile.
20. Local screen: Open Files, Import Video, Android device scan, recent-local resume, and Auto Search Subtitles toggle.
21. Branding: Android/iOS app label, launcher icon, playback notification title and Android TV banner show El-Nemr Language.

## Known quality boundary

Shadow/Role Play currently score recognized words against the expected text. This is useful for speech-production practice but is not a phoneme-level pronunciation diagnosis. Full ASS karaoke/vector positioning and bitmap PGS/DVB subtitles are also outside the independent learning-layer renderer.
