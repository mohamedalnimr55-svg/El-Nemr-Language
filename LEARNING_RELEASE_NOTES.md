# Learning Edition 0.7.0

## Added

- Personalized **AI picks for you** row with multiple movie recommendations driven by learning language + local taste model.
- Compact movie cards with description, language/year/genre, learning-fit label, match percentage and a transparent “why this was recommended” explanation.
- Taste onboarding/tuning for favorite genres plus adaptive 👍/👎 and watch-choice signals stored locally.
- Explicit dislikes suppress the title and reduce similar-genre affinity; casual opens are only weak positive signals.

- Netflix-style **Discover** tab with target-language-first Movies, Series/TV, Sports & matches, Documentaries, News, Kids and Learning rows.
- Global search with `All` plus category filters; “All languages” still ranks the learning language first.
- Separate **Explore other languages** row so off-target content is one tap away without changing the learner goal.
- Internet Archive + Wikimedia Commons no-key providers, open-license filtering, direct playable media resolution, and Internet Archive subtitle-sidecar import.
- Cross-language warning: a Japanese video can be played while learning Korean and the stored target remains Korean.
- Progressive catalog loading, in-memory discovery cache, provider-failure isolation and explicit-adult result filtering.
- Cross-engine unlimited text subtitle layers with independent drag/pinch/delay/visibility/lock and per-video persistence.
- Learning Studio with Watch, Learn, Listening, Shadow, Role Play, Test and Smart Coach modes.
- Automatic OpenSubtitles source/native-language acquisition.
- OpenAI-compatible timed ASR fallback with speech-language detection from provider output.
- Free on-device subtitle translation on Android/iOS via Google ML Kit, with OpenAI-compatible translation fallback and contextual AI Tutor.
- Sentence-exact replay and three-stage subtitle ladder practice.
- Adaptive Smart Coach based on stored performance and segment difficulty, including temporary per-segment playback-rate adjustment.
- Learning timeline with difficulty/progress markers.
- Scene-based video flashcards with spaced-repetition scheduling.
- Android/iOS microphone speech recognition for spoken answers and shadowing.
- Offline text-language inference for unnamed subtitle files (script + conservative lexical scoring).
- Live Learning Studio synchronization while the video continues playing, with stale quiz/feedback reset on segment transitions.
- Detailed answer diagnostics showing missing/expected and changed/extra words, not only a percentage.
- Direction-aware native subtitle rendering (RTL/LTR).
- New unit tests for learning parsers, timeline alignment, scoring, language detection, persistence, flashcards and adaptive policy.

## Platform

- Android minSdk: 26 (Android 8.0).
- iOS deployment target: 17.0 (upstream baseline).

## Translation privacy

- On-device translation downloads supported language models once and translates subtitle text locally; it does not require an API key.
- If on-device translation is unsupported or fails, an explicitly configured AI endpoint may be used as fallback.

## Verification in this workspace

- Structural delimiter checks passed for all new/modified Dart/Swift/Kotlin files.
- `swiftc -parse` passed for the modified iOS Swift sources.
- AndroidManifest.xml and iOS Info.plist parse successfully.
- A full Flutter/Gradle/Xcode build could not be executed in this container because the Flutter SDK/Android Gradle wrapper/Xcode are not installed here. Run the commands in `scripts/verify_learning_edition.sh` in a Flutter development environment before signing a release binary.
