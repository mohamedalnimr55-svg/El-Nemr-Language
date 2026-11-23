#!/usr/bin/env bash
set -euo pipefail

# External SDK downloads sometimes return incomplete NDK archives.
# Limit retries to this SDK install step, never to failed Flutter tests.
if (( $# == 0 )); then
  echo 'Usage: retry_android_sdk_install.sh <sdk package> [more packages...]' >&2
  exit 2
fi

sdk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$sdk_root" || ! -d "$sdk_root" ]]; then
  echo 'Android SDK root is missing.' >&2
  exit 2
fi
sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "$sdkmanager" ]]; then
  sdkmanager="$(command -v sdkmanager)"
fi

# sdkmanager exits when it has read the licenses; yes then gets SIGPIPE.
yes | "$sdkmanager" --licenses >/dev/null || true

for attempt in 1 2 3; do
  echo "Android SDK installation attempt $attempt/3"
  if "$sdkmanager" "$@"; then
    echo 'Android SDK packages installed successfully.'
    exit 0
  fi
  if (( attempt == 3 )); then
    echo 'Android SDK installation failed after three attempts.' >&2
    exit 1
  fi
  # Remove only a partial NDK folder with no source.properties, within the
  # ephemeral GitHub runner. Never delete an already installed valid NDK.
  ndk_version="${NDK_VERSION:-28.2.13676358}"
  partial_ndk="$sdk_root/ndk/$ndk_version"
  if [[ -d "$partial_ndk" && ! -s "$partial_ndk/source.properties" ]]; then
    echo "Removing incomplete NDK package: $ndk_version"
    rm -rf -- "$partial_ndk"
  fi
  delay=$((attempt * 12))
  echo "Retrying Android SDK download after ${delay}s..."
  sleep "$delay"
done
