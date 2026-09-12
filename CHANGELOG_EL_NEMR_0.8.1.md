# El-Nemr Language 0.8.1

CI/analyzer stabilization release.

- Fixed malformed RegExp end anchors that caused Dart `missing_identifier` errors.
- Replaced invalid `List.reverse()` calls with ordered `reversed.toList()` results.
- Removed all analyzer issues reported by the Android CI run: braces, deprecated Color serialization, DropdownButtonFormField initialization, `indexOf` containment lint, and callback underscore lints.
- Updated GitHub Actions to Node 24-era action majors (`checkout@v7`, `setup-java@v6`, `setup-android@v4`, `cache@v6`, `upload-artifact@v7`).
- Kept Android API 36 / Java 17 / Flutter 3.47.2 / NDK 28.2.13676358.
