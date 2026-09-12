# El-Nemr Language — product notes

El-Nemr Language is an offline-first, AI-assisted language-learning video player and a GPLv3 derivative of the open-source DreamPlayer project.

## Product identity

- Product: **El-Nemr Language**
- Android application ID / namespace: `com.elnemr.language`
- Core learning requires no API key.

## Learning pipeline

When Auto Learning Subtitles is enabled, the player can prepare a lesson from the video's own soundtrack:

`video → native audio extraction → 16 kHz WAV → on-device Whisper → timed original transcript → on-device translation → multi-subtitle learning layers`

The first Whisper/translation-model download requires internet. The downloaded models are reused on-device afterward. Authenticated or explicitly self-signed HTTP media is staged temporarily as a full local copy before native audio extraction, then deleted; this path needs enough temporary free storage.

## Navigation

- **Home** — continue watching and library.
- **Discover** — free/open content prioritized by the learning language and taste profile.
- **Search** — global discovery search.
- **Local** — open/import files, MediaStore scan, recent videos, Auto Learning Subtitles.
- **Profile** — learning profile, Offline AI readiness, Daily Review, playback settings, and optional online integrations.

## Subtitles

Local learning subtitle generation is enabled by default. OpenSubtitles is a separate optional enhancement and is disabled by default unless the user enables online auto-search and an API key is configured.

## Learning modes

The five primary modes are Watch, Learn, Listen, Speak, and Test. Smart Coach is an assist layer above the modes. Immersion Auto cycles modes during a session. Role Play and Shadowing live inside Speak.

## Platform baseline

RC3 release CI is pinned to Flutter 3.44.9 / Dart 3.12.2 to avoid a currently confirmed Flutter 3.47.x Android launch regression on older Android releases.

Android 8.0 (API 26) minimum. Android 10+ and 4–6 GB RAM are recommended for local Whisper transcription. Strict platform on-device microphone recognition is used only when the OS exposes a verifiable on-device recognizer (Android 12+/API 31+; supported iOS configurations); otherwise typed practice remains available and microphone audio is not silently sent to a network recognizer. iOS remains supported by the source tree's current deployment target.

## Legal

Upstream and third-party attribution remains in `LICENSE`, `NOTICE`, and the Legal/Open-source licenses screen as required. It is intentionally separate from product branding.
