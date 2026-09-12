# El-Nemr Language 0.9.1 RC2

Release hardening after the RC1 packaging audit.

## Fixed / hardened
- Restored and package-verified `.github/workflows/android.yml`; release ZIP creation now fails if the workflow is missing.
- Added Offline AI readiness UI for pre-downloading/checking the Whisper speech model and the learner's primary ML Kit translation models.
- Transcription now uses the explicitly managed Whisper model directory, giving predictable first-download progress and offline reuse.
- Clarified throughout the UI/docs that TMDB, OpenSubtitles, SIMKL and cloud tutor services are optional.
- Rewrote the root README and learning architecture docs around El-Nemr Language while retaining required upstream attribution in legal files.
- Updated NOTICE for permission_handler 12.0.3, Whisper Kit, ML Kit translation and path_provider.
- Silenced the harmless `yes: Broken pipe` message during Android SDK license setup.
- Bumped app version to 0.9.1+5.

## Release gate
Three independent Android CI validation passes remain mandatory. Each pass runs release audits, Flutter analyze/tests, APK + AAB release builds and APK signature verification.
