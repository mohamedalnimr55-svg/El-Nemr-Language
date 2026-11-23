#!/usr/bin/env bash
set -euo pipefail
# Current-release structural gate. Static contract checks complement,
# but never replace, Flutter tests, native builds, and physical-device QA.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
scope="${1:-android}"
case "$scope" in android|ios|full) ;; *) echo "Unknown audit scope: $scope" >&2; exit 2 ;; esac
fail() { echo "RELEASE AUDIT FAILED [$scope]: $*" >&2; exit 1; }
require_file() { [[ -s "$1" ]] || fail "required file missing or empty: $1"; }
require_match() { require_file "$2"; grep -qE -- "$1" "$2" || fail "$2: missing expected source pattern $1"; }
forbid_match() { require_file "$2"; ! grep -qE -- "$1" "$2" || fail "$2: forbidden source pattern $1"; }

for file in pubspec.yaml lib/learning/services/transcription_service.dart \
  lib/learning/services/audio_extraction_service.dart \
  lib/learning/services/offline_speech_model_service.dart \
  lib/learning/services/vocabulary_store.dart \
  lib/learning/widgets/learning_studio_sheet.dart \
  scripts/feature_wiring_audit.py scripts/resolved_dependency_audit.py; do
  require_file "$file"
done
require_match 'Whisper\(' lib/learning/services/transcription_service.dart
require_match 'AudioExtractionService.extractToWav' lib/learning/services/transcription_service.dart
require_match 'OfflineSpeechModelService.ensureDownloaded' lib/learning/services/transcription_service.dart
require_match 'whisperLanguage\(languageHint\)' lib/learning/services/transcription_service.dart
require_match 'learning\.flashcards\.' lib/learning/services/video_flashcard_store.dart
require_match 'LearningWriteQueue.run' lib/learning/services/video_flashcard_store.dart
require_match 'LearningWriteQueue.run' lib/learning/services/vocabulary_store.dart

if [[ "$scope" == android || "$scope" == full ]]; then
  for file in .github/workflows/android.yml android/app/build.gradle.kts \
      android/gradlew android/gradle/wrapper/gradle-wrapper.properties \
      android/app/src/main/AndroidManifest.xml \
      android/app/src/main/kotlin/com/elnemr/language/AudioExtractor.kt \
      android/app/src/main/kotlin/com/elnemr/language/SpeechCoach.kt; do
    require_file "$file"
  done
  require_match 'applicationId = "com\.elnemr\.language"' android/app/build.gradle.kts
  require_match 'minSdk = 26' android/app/build.gradle.kts
  require_match 'compileSdk = 36' android/app/build.gradle.kts
  require_match 'android.permission.RECORD_AUDIO' android/app/src/main/AndroidManifest.xml
  forbid_match 'MANAGE_EXTERNAL_STORAGE' android/app/src/main/AndroidManifest.xml
  require_match 'elnemr/audio_extractor' android/app/src/main/kotlin/com/elnemr/language/AudioExtractor.kt
  require_match 'createOnDeviceSpeechRecognizer' android/app/src/main/kotlin/com/elnemr/language/SpeechCoach.kt
  forbid_match 'signingConfigs.getByName\("debug"\)' android/app/build.gradle.kts
  require_match 'Configure persistent production signing' .github/workflows/android.yml
  require_match 'Generate isolated validation signing key' .github/workflows/android.yml
  require_match 'SIGNING_KEYSTORE_BASE64:.*secrets.ANDROID_KEYSTORE_BASE64' .github/workflows/android.yml
  require_match 'flutter analyze --no-fatal-infos' .github/workflows/android.yml
  require_match 'flutter test --no-pub' .github/workflows/android.yml
  require_match 'flutter build apk --release --no-pub' .github/workflows/android.yml
  require_match 'flutter build appbundle --release --no-pub' .github/workflows/android.yml
  require_match 'apksigner|APKSIGNER' .github/workflows/android.yml
  require_match 'Audit Android release and feature wiring' .github/workflows/android.yml
fi

if [[ "$scope" == ios || "$scope" == full ]]; then
  require_file ios/Runner/AppDelegate.swift
  require_file ios/Runner/Info.plist
  require_match 'elnemr/audio_extractor' ios/Runner/AppDelegate.swift
fi

# The existing audit verifies the user-facing discovery/learning controls
# and native-to-Flutter wiring beyond the narrower release-specific gates.
python3 scripts/feature_wiring_audit.py || fail 'feature wiring audit failed'
echo "RELEASE AUDIT PASS [$scope] — structural checks only; physical device QA still required"
