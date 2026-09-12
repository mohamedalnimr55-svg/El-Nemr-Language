#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

JAR="android/gradle/wrapper/gradle-wrapper.jar"
PRIMARY_URL="https://raw.githubusercontent.com/gradle/gradle/v9.1.0/gradle/wrapper/gradle-wrapper.jar"
EXPECTED_SHA256="76805e32c009c0cf0dd5d206bddc9fb22ea42e84db904b764f3047de095493f3"

mkdir -p "$(dirname "$JAR")"

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

verify_jar() {
  [[ -f "$JAR" ]] || return 1
  [[ "$(sha256_file "$JAR")" == "$EXPECTED_SHA256" ]]
}

if ! verify_jar; then
  command -v curl >/dev/null 2>&1 || {
    echo 'curl is required to restore the Gradle Wrapper JAR.' >&2
    exit 1
  }
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  downloaded=0
  for url in "$PRIMARY_URL"; do
    rm -f "$tmp"
    if curl --fail --location --silent --show-error \
      --retry 5 --retry-all-errors --connect-timeout 20 \
      --output "$tmp" "$url"; then
      actual="$(sha256_file "$tmp")"
      if [[ "$actual" == "$EXPECTED_SHA256" ]]; then
        downloaded=1
        break
      fi
      echo "Gradle Wrapper JAR checksum mismatch from $url: $actual" >&2
    fi
  done
  if [[ "$downloaded" != 1 ]]; then
    echo 'Could not restore a verified Gradle 9.1.0 Wrapper JAR.' >&2
    exit 1
  fi
  mv "$tmp" "$JAR"
  trap - EXIT
fi

chmod +x android/gradlew
printf 'Gradle Wrapper ready: Gradle 9.1.0 JAR SHA-256 %s\n' "$EXPECTED_SHA256"
