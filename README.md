# El-Nemr Language

**El-Nemr Language** is a mobile video player designed around language learning from real movies, series, sports, documentaries, and local video files.


## What works without API keys

- Android/iOS video playback and local/network files.
- First-run learner profile: native language, learning language, CEFR level, goals, and content taste.
- Native audio extraction to 16 kHz PCM WAV.
- On-device Whisper transcription with timed subtitles and automatic spoken-language detection.
- On-device ML Kit translation for supported language pairs.
- Multi-subtitle learning layers: original + learning language + native/helper language, with independent position, scale, delay, visibility, and lock.
- Watch / Learn / Listen / Speak / Test modes. Microphone speaking practice is strict on-device-only when the platform exposes a verifiable offline recognizer; it does not silently fall back to cloud speech.
- Smart Coach and Immersion Auto mode.
- Tap-word translation, vocabulary saving, spaced repetition, Daily Review, video flashcards, dictation, shadowing, and basic role-play.
- Local/open Discover catalog and taste-aware recommendations.

The Whisper model and required ML Kit translation language models need an internet connection the first time they are downloaded. Once present on the device, the related learning flow can work offline. For authenticated/self-signed HTTP media, local transcription first stages a temporary full media copy using the same headers/trust opt-in, then deletes that copy after audio extraction; enough temporary free space is therefore required for that case.

## Optional online enhancements

TMDB, OpenSubtitles, SIMKL, and an OpenAI-compatible/self-hosted tutor endpoint are optional. They are not required for the core learning pipeline. See `.env.example`.

## Android

- Minimum: **Android 8.0 / API 26**
- compileSdk / targetSdk: **36**
- Recommended for local AI: Android 10+, 4 GB RAM minimum; 6 GB+ preferred.

## CI / release validation

### Release toolchain pin

RC3 pins CI to **Flutter 3.44.9 / Dart 3.12.2**. This is intentional: the project SDK constraint is `^3.12.2`, and Flutter 3.47.x currently has a confirmed Android `AccessibilityBridge` class-verification launch regression on pre-API-34 devices for which the reported working workaround is 3.44.9. The pin should be revisited only after the upstream regression is fixed and device-smoke-tested.


`.github/workflows/android.yml` runs three independent validation passes. Each pass resolves dependencies, audits the resolved package versions, runs release/feature audits, `flutter analyze`, the Flutter test suite, builds a signed release APK and AAB, verifies the APK signature, and uploads the generated `pubspec.lock` with the build artifacts.

RC3 intentionally does **not** ship the stale RC2 `pubspec.lock`. The first real Flutter resolution generates a new lock, then `scripts/resolved_dependency_audit.py` gates the build before analyze/tests/build. This avoids presenting an unverified hand-edited lock as reproducible.

For persistent production signing, configure these GitHub secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Without those secrets, CI creates an ephemeral non-debug validation key. Those APKs are installable for testing but should not be used as a long-term production signing identity.

For optional signed iOS/TestFlight validation in `.github/workflows/ios.yml`, configure `IOS_CERT_BASE64`, `IOS_CERT_PASSWORD`, `IOS_PROFILE_BASE64`. The workflow validates the provisioning profile's team and `com.elnemr.language` application identifier, uses manual signing for Runner, verifies the signed app with `codesign`, and publishes an IPA checksum.

## Build locally

```bash
flutter pub get
flutter gen-l10n
bash scripts/release_audit.sh
python3 scripts/feature_wiring_audit.py
flutter analyze
flutter test
flutter build apk --release
```

## License and upstream attribution

El-Nemr Language is a GPLv3 derivative of the open-source DreamPlayer project. Required upstream copyright and open-source attribution are preserved in `LICENSE`, `NOTICE`, and the in-app Legal/Open-source licenses screen. Product branding and runtime identifiers use El-Nemr Language.
