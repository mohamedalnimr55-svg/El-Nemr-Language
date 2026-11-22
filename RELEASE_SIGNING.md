# El-Nemr Language — Android signing and update identity

## Two distinct build modes

- Pull requests, `full-native-build`, and manual workflow runs: fresh **temporary validation key** generated inside CI. Installable for device QA, but each build uses a different certificate and will not update a previously installed validation APK without uninstalling it (which may erase local learning data).
- Pushes to `main`: **persistent production keystore** from repository Actions secrets. If the four secrets are missing, production build **fails**, rather than accidentally changing the app's update identity.

## Owner-only setup before distribution

1. Generate an Android release keystore in a secure offline environment, or use the existing production keystore **if this app has ever been shipped**. Changing the key may make updates impossible.
2. Store the keystore and passwords in a secure backup location. Never commit the binary, expose private keys to screenshots/chats, or reuse a disposable CI keystore.
3. Configure GitHub repository Settings → Secrets and variables → Actions → New repository secret:
   - `ANDROID_KEYSTORE_BASE64`: base64 encoding of the entire binary keystore file, with no extra text
   - `ANDROID_KEYSTORE_PASSWORD`: keystore password
   - `ANDROID_KEY_ALIAS`: release key alias
   - `ANDROID_KEY_PASSWORD`: release key password
4. On the first authorized `main` push, CI verifies the keystore and signing alias before building. Check the workflow summary shows `persistent production key`, then archive the signed APK/AAB and record its certificate fingerprint.
5. For later releases, preserve the same keystore, alias, application ID `com.elnemr.language`, and increment Android `versionCode` before publishing.

## Suggested preparation commands (run locally, not in a chat)

```bash
keytool -genkeypair -v -keystore elnemr-production.jks -alias elnemr-production -keyalg RSA -keysize 3072 -validity 10000
base64 -w 0 elnemr-production.jks > keystore.base64.txt  # Linux
keytool -list -v -keystore elnemr-production.jks -alias elnemr-production
```

On macOS use `base64 < elnemr-production.jks | tr -d '\n'` to produce the single-line secret. Delete any intermediate plaintext/base64 copies from shared devices after setup; GitHub secrets contain sensitive material.

**Not verified by CI:** production updates over an existing install, microphone/offline speech availability on device, model downloads/transcription speed, video playback on target codecs, and user acceptance. Run physical-device QA before shipping. A successful AAB build does not authorize publication.
