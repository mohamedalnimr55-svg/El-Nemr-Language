#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(awk '/^version:/{print $2; exit}' "$ROOT/pubspec.yaml" | tr '+' '-')"
OUT="${1:-$ROOT/../El-Nemr-Language-${VERSION}-source.zip}"

cd "$ROOT"
bash scripts/release_audit.sh full
python3 scripts/static_validate.py .
python3 scripts/feature_wiring_audit.py .

rm -f "$OUT"
python3 - "$ROOT" "$OUT" <<'PY'
from pathlib import Path
import sys, zipfile
root=Path(sys.argv[1]).resolve(); out=Path(sys.argv[2]).resolve()
skip={'.dart_tool','build','.git','.idea','__pycache__','.pytest_cache'}
with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in sorted(root.rglob('*')):
        rel=p.relative_to(root)
        if any(part in skip for part in rel.parts):
            continue
        if p.is_file():
            z.write(p, rel.as_posix())
with zipfile.ZipFile(out) as z:
    required={'CHANGELOG_EL_NEMR_0.9.1_RC3.md','.env.example','.github/workflows/android.yml','.github/workflows/ios.yml','.github/workflows/release.yml','pubspec.yaml','gradlew','gradlew.bat','android/gradlew','android/gradlew.bat','android/gradle/wrapper/gradle-wrapper.properties','scripts/bootstrap_gradle_wrapper.sh','scripts/release_audit.sh','scripts/feature_wiring_audit.py','scripts/resolved_dependency_audit.py','scripts/rc3_source_validation.sh','lib/learning/services/offline_speech_model_service.dart','lib/learning/screens/offline_ai_setup_screen.dart'}
    names=set(z.namelist())
    missing=required-names
    if missing:
        raise SystemExit(f'ZIP missing required files: {sorted(missing)}')
    bad=z.testzip()
    if bad:
        raise SystemExit(f'ZIP CRC failed: {bad}')
print(out)
PY
sha256sum "$OUT" > "$OUT.sha256"
echo "Release package ready: $OUT"
