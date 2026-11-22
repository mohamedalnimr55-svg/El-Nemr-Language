#!/usr/bin/env bash
set -euo pipefail

# GitHub-hosted runners sometimes hit Maven Central HTTP 429 while Gradle
# resolves native Android dependencies. Retry ONLY that transient failure;
# compilation errors must fail immediately and remain visible in CI.
if (( $# == 0 )); then
  echo 'Usage: retry_android_build.sh <command> [args...]' >&2
  exit 64
fi
attempts="${ANDROID_BUILD_RETRIES:-3}"
base_delay="${ANDROID_BUILD_RETRY_DELAY_SECONDS:-45}"
if ! [[ "$attempts" =~ ^[1-9][0-9]*$ ]] || (( attempts > 5 )) ||
    ! [[ "$base_delay" =~ ^[0-9]+$ ]] || (( base_delay > 600 )); then
  echo 'Invalid Android build retry configuration.' >&2
  exit 64
fi

for ((try = 1; try <= attempts; try++)); do
  log="$(mktemp)"
  echo "::group::Android native build attempt ${try}/${attempts}"
  if "$@" 2>&1 | tee "$log"; then
    echo '::endgroup::'
    rm -f "$log"
    exit 0
  fi
  echo '::endgroup::'
  if (( try < attempts )) &&
      grep -Eiq '(status code 429|HTTP[^[:digit:]]*429|Too Many Requests)' "$log"; then
    wait_seconds=$((base_delay * try))
    echo "::warning::Android dependency host returned HTTP 429. Retrying build attempt $((try + 1))/${attempts} after ${wait_seconds}s."
    rm -f "$log"
    sleep "$wait_seconds"
  else
    echo '::error::Android build failed; not retrying non-429 errors or exhausted retry limit.'
    rm -f "$log"
    exit 1
  fi
done
