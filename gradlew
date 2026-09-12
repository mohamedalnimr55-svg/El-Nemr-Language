#!/usr/bin/env sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

# Keep legacy/root Gradle invocations compatible with the Flutter Android project.
# Restore the Wrapper JAR on clean checkouts before delegating.
if [ ! -f "$ROOT_DIR/android/gradle/wrapper/gradle-wrapper.jar" ]; then
  if command -v bash >/dev/null 2>&1; then
    bash "$ROOT_DIR/scripts/bootstrap_gradle_wrapper.sh"
  else
    echo "Gradle Wrapper JAR is missing and bash is unavailable." >&2
    exit 1
  fi
fi

# Gradle 9 requires Java 17+. New CI installs Java 17 explicitly, but this
# compatibility shim also recovers from older GitHub workflows that selected JDK 11.
java_major() {
  "$1" -version 2>&1 | awk -F '[\".]' '/version/ { if ($2 == "1") print $3; else print $2; exit }'
}

JAVA_CMD="${JAVA_HOME:+$JAVA_HOME/bin/}java"
if ! command -v "$JAVA_CMD" >/dev/null 2>&1 && [ ! -x "$JAVA_CMD" ]; then
  JAVA_CMD=java
fi
MAJOR=$(java_major "$JAVA_CMD" 2>/dev/null || echo 0)
case "$MAJOR" in ''|*[!0-9]*) MAJOR=0;; esac
if [ "$MAJOR" -lt 17 ]; then
  for CANDIDATE in \
    "${JAVA_HOME_21_X64:-}" \
    "${JAVA_HOME_17_X64:-}" \
    /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/21*/x64 \
    /opt/hostedtoolcache/Java_Temurin-Hotspot_jdk/17*/x64 \
    /usr/lib/jvm/temurin-21-jdk-amd64 \
    /usr/lib/jvm/temurin-17-jdk-amd64 \
    /usr/lib/jvm/java-21-openjdk-amd64 \
    /usr/lib/jvm/java-17-openjdk-amd64
  do
    [ -n "$CANDIDATE" ] || continue
    if [ -x "$CANDIDATE/bin/java" ]; then
      CANDIDATE_MAJOR=$(java_major "$CANDIDATE/bin/java" 2>/dev/null || echo 0)
      case "$CANDIDATE_MAJOR" in ''|*[!0-9]*) CANDIDATE_MAJOR=0;; esac
      if [ "$CANDIDATE_MAJOR" -ge 17 ]; then
        JAVA_HOME="$CANDIDATE"
        export JAVA_HOME
        PATH="$JAVA_HOME/bin:$PATH"
        export PATH
        break
      fi
    fi
  done
fi

FINAL_JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"
if ! command -v "$FINAL_JAVA" >/dev/null 2>&1 && [ ! -x "$FINAL_JAVA" ]; then FINAL_JAVA=java; fi
FINAL_MAJOR=$(java_major "$FINAL_JAVA" 2>/dev/null || echo 0)
case "$FINAL_MAJOR" in ''|*[!0-9]*) FINAL_MAJOR=0;; esac
if [ "$FINAL_MAJOR" -lt 17 ]; then
  echo "Gradle 9.1.0 requires Java 17 or newer. Current Java major: $FINAL_MAJOR" >&2
  echo "Use the included Android Release Validation workflow, which installs Temurin 17." >&2
  exit 1
fi

# Use sh explicitly so loss of the executable bit on android/gradlew cannot
# break a legacy workflow that invokes the root wrapper.
cd "$ROOT_DIR/android"
exec sh ./gradlew "$@"
