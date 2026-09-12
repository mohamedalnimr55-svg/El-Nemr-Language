# El-Nemr Language 0.9.0 RC

Release-candidate hardening focused on offline-first language learning and Android release reliability.

## Core learning
- First-run learner onboarding (native language, target language, CEFR level, goals, content taste).
- Five core modes only: Watch, Learn, Listen, Speak, Test.
- Smart Coach is an independent assist layer; Immersion Auto cycles the five modes.
- Multi-subtitle layers are exposed from the normal subtitle menu and can be moved, resized, delayed, hidden, and locked independently.
- Auto Learning Subtitles: local audio extraction -> local Whisper transcription/language detection -> on-device translation.
- When all three differ, video language + learning language + native language are prepared as three independent layers.
- Tap-word local translation, vocabulary saving, SRS review, and Daily Review.
- Local Coach fallback works without an LLM endpoint.
- Speaking feedback reports word match, completeness, and pace without claiming phoneme/accent grading.
- Best-effort local content identity uses filename/episode metadata plus detected audio language; it does not claim acoustic movie fingerprint recognition.

## Mobile / privacy
- Android modern storage uses MediaStore content URIs and SAF folder access; broad All Files Access is not requested.
- Android and iOS native audio extraction produce 16 kHz mono WAV for local ASR.
- Core learning does not require OpenSubtitles, TMDB, or a cloud LLM API key; these remain optional enhancements.

## Release hardening
- Runtime identity moved to com.elnemr.language.
- Production signing supports persistent GitHub secrets; CI falls back to an ephemeral non-debug release key for validation builds.
- Android compileSdk/targetSdk 36, minSdk 26 (Android 8.0+).
- permission_handler pinned to 12.0.3 with permission_handler_android 13.x to avoid the API-37 requirement introduced in permission_handler 13.x.
- The dependency lock is checked by CI after `flutter pub get`.
- Three independent CI validation passes each run: dependency resolution, release audit, Flutter analyze, tests, signed APK build, AAB build, and APK signature verification.
