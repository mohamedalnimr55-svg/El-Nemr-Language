#!/usr/bin/env bash
set -euo pipefail

# Checks signed Release (AOT/R8) Android native startup, not device QA or playback.
PACKAGE=com.elnemr.language
APK=build/app/outputs/flutter-apk/app-release.apk
if (( $# > 0 )); then APK="$1"; fi
OUTPUT_DIR=android-emulator-smoke-results
mkdir -p "$OUTPUT_DIR"

collect_diagnostics() {
  local code=$?
  adb logcat -d -v threadtime > "$OUTPUT_DIR/logcat.txt" 2>&1 || true
  adb shell dumpsys activity activities > "$OUTPUT_DIR/activities.txt" 2>&1 || true
  adb shell screencap -p /sdcard/elnemr-smoke.png >/dev/null 2>&1 || true
  adb pull /sdcard/elnemr-smoke.png "$OUTPUT_DIR/screen.png" >/dev/null 2>&1 || true
  printf 'smoke_exit_code=%s\n' "$code" > "$OUTPUT_DIR/result.txt"
}
trap collect_diagnostics EXIT

test -s "$APK" || { echo "APK not found: $APK" >&2; exit 2; }
adb wait-for-device
booted=0
for _ in $(seq 1 90); do
  if [[ "$(adb shell getprop sys.boot_completed | tr -d '\r')" == 1 ]]; then
    booted=1
    break
  fi
  sleep 2
done
if (( booted == 0 )); then
  echo 'Android emulator never reported boot completed.' >&2
  exit 1
fi
printf 'Emulator Android: %s\n' "$(adb shell getprop ro.build.version.release | tr -d '\r')"
actual_api="$(adb shell getprop ro.build.version.sdk | tr -d '\r')"
printf 'Emulator API level: %s\n' "$actual_api"
printf 'Emulator ABI: %s\n' "$(adb shell getprop ro.product.cpu.abi | tr -d '\r')"
printf 'Release APK SHA-256: '
sha256sum "$APK"
if [[ -n "${EXPECTED_API_LEVEL:-}" && "$actual_api" != "$EXPECTED_API_LEVEL" ]]; then
  echo "Wrong emulator Android API: expected $EXPECTED_API_LEVEL, got $actual_api" >&2
  exit 1
fi

# The APK uses the workflow's one-time validation key; no production secret.
adb install -r "$APK" | tee "$OUTPUT_DIR/install.txt"
grep -q '^Success' "$OUTPUT_DIR/install.txt"
adb shell pm path "$PACKAGE" | grep -q '^package:'

launch_and_verify() {
  local name="$1"
  adb shell am force-stop "$PACKAGE"
  adb logcat -c
  adb shell am start -W -n "$PACKAGE/.MainActivity" | tee "$OUTPUT_DIR/$name.txt"
  grep -q '^Status: ok' "$OUTPUT_DIR/$name.txt" || {
    echo "Android ActivityManager did not report successful $name." >&2
    exit 1
  }
  # Check for initialization crashes that occur after am start returns.
  sleep 15
  local pid
  pid="$(adb shell pidof -s "$PACKAGE" | tr -d '\r' || true)"
  if [[ -z "$pid" ]]; then
    echo "$name: app process died after launch." >&2
    exit 1
  fi
  echo "$name: process $pid survived 15 seconds."
}

launch_and_verify first_launch
launch_and_verify restart
echo 'PASS: APK installed; launcher and cold restart survived in Android emulator.'
