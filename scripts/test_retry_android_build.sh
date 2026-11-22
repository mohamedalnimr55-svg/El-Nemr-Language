#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/mock_build.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
counter="$(cat "$RETRY_TEST_COUNTER")"
counter=$((counter + 1))
printf '%s' "$counter" > "$RETRY_TEST_COUNTER"
case "$RETRY_TEST_MODE" in
  success) printf 'Built successfully\n'; exit 0 ;;
  rate-limit) if ((counter < 3)); then printf 'Received status code 429 from server: Too Many Requests\n' >&2; exit 1; fi; printf 'Built successfully\n'; exit 0 ;;
  always-429) printf 'Could not GET. Received status code 429\n' >&2; exit 1 ;;
  code-error) printf 'Dart compilation failed\n' >&2; exit 1 ;;
  *) exit 3 ;;
esac
MOCK
chmod +x "$tmp/mock_build.sh"
export RETRY_TEST_COUNTER="$tmp/count"
export ANDROID_BUILD_RETRIES=3
export ANDROID_BUILD_RETRY_DELAY_SECONDS=0
assert_count() {
  if [[ "$(cat "$RETRY_TEST_COUNTER")" != "$1" ]]; then
    echo "Expected $1 build attempts, got $(cat "$RETRY_TEST_COUNTER")" >&2
    exit 1
  fi
}
printf 0 > "$RETRY_TEST_COUNTER"; export RETRY_TEST_MODE=success
bash retry_android_build.sh "$tmp/mock_build.sh" > "$tmp/result.log" 2>&1
assert_count 1
printf 0 > "$RETRY_TEST_COUNTER"; export RETRY_TEST_MODE=rate-limit
bash retry_android_build.sh "$tmp/mock_build.sh" > "$tmp/result.log" 2>&1
assert_count 3
printf 0 > "$RETRY_TEST_COUNTER"; export RETRY_TEST_MODE=always-429
if bash retry_android_build.sh "$tmp/mock_build.sh" > "$tmp/result.log" 2>&1; then
  echo 'Expected exhausted HTTP 429 retries to fail' >&2; exit 1
fi
assert_count 3
printf 0 > "$RETRY_TEST_COUNTER"; export RETRY_TEST_MODE=code-error
if bash retry_android_build.sh "$tmp/mock_build.sh" > "$tmp/result.log" 2>&1; then
  echo 'Expected non-429 error to fail' >&2; exit 1
fi
assert_count 1
printf 'Android dependency retry helper: 4/4 scenarios passed.\n'
