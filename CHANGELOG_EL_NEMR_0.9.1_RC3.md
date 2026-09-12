# El-Nemr Language 0.9.1 RC3

Release-candidate hardening after the RC2 source audit.

## Closed in RC3

- Protected/authenticated HTTP and WebDAV transcription now uses a Store-safe public-networking path: Dart stages a temporary local media copy with the same HTTP headers and explicit self-signed-certificate opt-in, native extraction works on that local file, and the staged media is deleted immediately afterward. No undocumented AVFoundation HTTP-header key is used.
- Speaking practice is strict **offline-first**. Android uses the platform on-device recognizer only when it is explicitly available (API 31+); iOS requires `supportsOnDeviceRecognition`. If offline recognition is unavailable, the app reports that condition instead of silently sending microphone audio to a network recognizer.
- Speaking copy now states exactly what is scored: recognized words, completeness and timing. It does not claim phoneme or accent scoring.
- Removed personal bylines and legacy donation/support strings from current user-facing branding while retaining license/legal attribution required by the inherited GPL project.
- Android CI's throwaway validation certificate now uses a generic CI identity.
- Audio-extraction regression tests cover the MethodChannel call contract and invalid/empty native output; static feature/release audits additionally gate protected-media staging, header propagation, self-signed opt-in, and temp-file cleanup wiring.
- Removed the unsupported `AVURLAssetHTTPHeaderFieldsKey` pattern from iOS media probing as well as audio extraction. HTTP/WebDAV metadata probing now uses the same supported Aether/WebDAV stack used by playback.
- Android HTTP/WebDAV metadata probing now uses Media3/OkHttp with the same request headers and explicit self-signed policy used by playback.
- FTP/SFTP metadata probing now uses the native seekable readers on both platforms instead of the old Dart HTTP-style fallback.
- iOS signing validation now extracts and validates the provisioning profile, Team ID and exact `com.elnemr.language` application identifier, applies manual Runner signing, verifies the resulting app with `codesign`, and emits an IPA checksum.
- Release CI is pinned to **Flutter 3.44.9 / Dart 3.12.2** to avoid the confirmed Flutter 3.47.x `AccessibilityBridge` pre-API-34 Android launch regression while preserving the project's Dart `^3.12.2` constraint.
- Gradle configuration cache is explicitly disabled until Flutter's currently open AGP-object capture issue is fixed.
- Build number advanced to `0.9.1+6`.

## Dependency lock policy

The four critical direct dependencies remain exact-pinned in `pubspec.yaml`: `whisper_kit 0.3.1`, `google_mlkit_translation 0.15.1`, `path_provider 2.1.5`, and `permission_handler 12.0.3`.

The known-stale RC2 `pubspec.lock` is deliberately not carried forward as if it were valid. A real Flutter environment must run `flutter pub get` followed immediately by `scripts/resolved_dependency_audit.py`; the audit fails if the four release pins or their critical transitive compatibility ranges differ. Android CI runs this gate independently in all three build passes and uploads the generated lock with its artifacts.

## Operational notes

- Protected/self-signed HTTP transcription temporarily needs free storage roughly comparable to the source media size because the authenticated source is staged before extraction.
- iOS audio extraction remains AVFoundation-backed. Containers/codecs outside AVFoundation's extraction support must be device-tested even when AetherEngine can play/probe them.

## Still intentionally not claimed

- No phoneme-level or accent-quality scoring.
- No reliable speaker diarization for ordinary mono movie audio; speaker-labelled subtitles are still the supported Role Play source.
- Signed iOS/TestFlight output requires the repository's Apple certificate/profile/team secrets and a macOS runner.
