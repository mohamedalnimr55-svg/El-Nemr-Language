#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

flutter pub get

dart format --output=none --set-exit-if-changed \
  lib/learning \
  lib/discover \
  lib/screens/discover_screen.dart \
  lib/screens/search_screen.dart \
  lib/screens/local_screen.dart \
  lib/screens/player_screen.dart \
  lib/widgets/el_nemr_brand.dart \
  lib/theme/app_theme.dart \
  test/learning_* \
  test/discovery_*

flutter analyze

flutter test \
  test/learning_subtitle_parser_test.dart \
  test/learning_subtitle_layer_test.dart \
  test/learning_engine_test.dart \
  test/learning_store_test.dart \
  test/learning_adaptive_policy_test.dart \
  test/learning_transcription_test.dart \
  test/learning_ai_service_test.dart \
  test/learning_language_detector_test.dart \
  test/discovery_language_test.dart \
  test/discovery_recommendation_test.dart

flutter build apk --debug

if [[ "$(uname -s)" == "Darwin" ]]; then
  # Regenerates Flutter Swift Package Manager integration before opening Xcode.
  flutter build ios --config-only --no-codesign
fi
