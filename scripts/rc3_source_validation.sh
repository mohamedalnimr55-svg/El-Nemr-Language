#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 scripts/static_validate.py .
python3 scripts/feature_wiring_audit.py .
bash scripts/release_audit.sh
tmp_pycache="$(mktemp -d)"
PYTHONPYCACHEPREFIX="$tmp_pycache" python3 -m py_compile scripts/*.py
rm -rf "$tmp_pycache"
for f in scripts/*.sh; do bash -n "$f"; done
bash -n android/gradlew

python3 - <<'PY'
from pathlib import Path
import json, plistlib, xml.etree.ElementTree as ET, yaml
for f in ['.github/workflows/android.yml','.github/workflows/ios.yml','.github/workflows/release.yml','pubspec.yaml']:
    yaml.safe_load(Path(f).read_text())
for p in Path('lib/l10n').glob('*.arb'):
    json.loads(p.read_text())
for p in Path('android/app/src').rglob('*.xml'):
    ET.parse(p)
with open('ios/Runner/Info.plist','rb') as f:
    plistlib.load(f)
print('STRUCTURED FILE PARSING PASS')
PY

if command -v swiftc >/dev/null 2>&1; then
  mapfile -t swift_files < <(find ios/Runner -type f -name '*.swift' | sort)
  if ((${#swift_files[@]})); then
    swiftc -frontend -parse "${swift_files[@]}" >/dev/null
    echo 'SWIFT PARSE PASS'
  fi
else
  echo 'SWIFT PARSE SKIPPED: swiftc unavailable'
fi

# Release hygiene: runtime/source paths must not reintroduce removed branding,
# broad storage permissions, unsupported AVFoundation header injection, or the
# known-stale toolchain pin.
! grep -RIEq 'Dr Mustafa|Mustafa Salah|supportGithub|supportRazorpay|Razorpay|github\.com/sponsors|made by' \
  lib android ios .github README.md EL_NEMR_LANGUAGE.md .env.example
! grep -RIEq 'MANAGE_EXTERNAL_STORAGE|ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION|hasAllFilesAccess|openAllFilesAccessSettings' \
  lib android/app/src/main
! grep -RIEq 'AVURLAssetHTTPHeaderFieldsKey' ios/Runner
! grep -RIEq "FLUTTER_VERSION: '3\.47\.2'|version: 0\.9\.1\+5" \
  .github pubspec.yaml README.md EL_NEMR_LANGUAGE.md scripts

echo 'RC3 SOURCE VALIDATION PASS'
