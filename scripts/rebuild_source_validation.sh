#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

required=(
  .env.example
  .github/workflows/android.yml
  .github/workflows/ios.yml
  .github/workflows/release.yml
  android/.gitignore
  gradlew
  gradlew.bat
  android/gradlew
  android/gradlew.bat
  android/gradle/wrapper/gradle-wrapper.properties
  scripts/bootstrap_gradle_wrapper.sh
  scripts/release_audit.sh
  scripts/resolved_dependency_audit.py
  scripts/feature_wiring_audit.py
)
missing=()
for f in "${required[@]}"; do [[ -f "$f" ]] || missing+=("$f"); done
if ((${#missing[@]})); then
  printf 'REBUILD VALIDATION FAILED: missing required files:\n' >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

bash scripts/release_audit.sh android
bash scripts/release_audit.sh ios
bash scripts/release_audit.sh full
PYTHONDONTWRITEBYTECODE=1 python3 scripts/static_validate.py .
PYTHONDONTWRITEBYTECODE=1 python3 scripts/feature_wiring_audit.py .

for f in scripts/*.sh gradlew android/gradlew; do bash -n "$f"; done
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
from pathlib import Path
for p in Path('scripts').glob('*.py'):
    compile(p.read_text(encoding='utf-8'), str(p), 'exec')
print('PYTHON SYNTAX PASS')
PY

python3 - <<'PY'
from pathlib import Path
import json, plistlib, xml.etree.ElementTree as ET, yaml
for p in Path('.github/workflows').glob('*.yml'):
    yaml.safe_load(p.read_text(encoding='utf-8'))
yaml.safe_load(Path('pubspec.yaml').read_text(encoding='utf-8'))
for p in Path('lib/l10n').glob('*.arb'):
    json.loads(p.read_text(encoding='utf-8'))
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

# Old generic Android starter-workflow invocations must not exist in the included workflows.
if grep -RIEq 'chmod[[:space:]]+\+x[[:space:]]+gradlew|(^|[[:space:]])\./gradlew[[:space:]]+build' .github/workflows; then
  echo 'REBUILD VALIDATION FAILED: legacy generic Android CI invocation found' >&2
  exit 1
fi
if grep -RIEq 'java-version:[[:space:]]*11' .github/workflows; then
  echo 'REBUILD VALIDATION FAILED: Java 11 workflow pin found' >&2
  exit 1
fi

# Prove Android validation does not depend on unrelated hidden/iOS workflow files.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -a . "$tmp/repo"
rm -f "$tmp/repo/.env.example" "$tmp/repo/.github/workflows/ios.yml" \
      "$tmp/repo/.github/workflows/release.yml" "$tmp/repo/android/.gitignore"
(
  cd "$tmp/repo"
  bash scripts/release_audit.sh android
)
rm -rf "$tmp"
trap - EXIT

echo 'ANDROID AUDIT INDEPENDENCE PASS'

# Reproduce the legacy GitHub pattern that previously failed with exit 126.
legacy_tmp="$(mktemp -d)"
trap 'rm -rf "$legacy_tmp"' EXIT
mkdir -p "$legacy_tmp/android/gradle/wrapper" "$legacy_tmp/scripts"
cp gradlew "$legacy_tmp/gradlew"
cat > "$legacy_tmp/android/gradlew" <<'SH'
#!/usr/bin/env sh
printf 'LEGACY_DELEGATION_OK:%s:%s\n' "$(basename "$PWD")" "$*"
SH
chmod 0644 "$legacy_tmp/android/gradlew"
: > "$legacy_tmp/android/gradle/wrapper/gradle-wrapper.jar"
chmod +x "$legacy_tmp/gradlew"
legacy_out="$(cd "$legacy_tmp" && ./gradlew build)"
[[ "$legacy_out" == 'LEGACY_DELEGATION_OK:android:build' ]] || {
  echo "REBUILD VALIDATION FAILED: root Gradle compatibility shim did not enter android/ and delegate via sh: $legacy_out" >&2
  exit 1
}
rm -rf "$legacy_tmp"
trap - EXIT
echo 'LEGACY ROOT GRADLE PERMISSION TEST PASS'

echo 'REBUILD SOURCE VALIDATION PASS'
