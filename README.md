# Qabasic Payment Forwarder

A hardened Android fork of [ju4700/sms-forwarder-v2](https://github.com/ju4700/sms-forwarder-v2) for receiving-wallet bKash payment receipts. Flutter UI, native Android capture and WorkManager delivery. BSD 3-Clause license retained.

## What changed

- Only exact bKash / 16247 SMS sender addresses and complete incoming-credit receipt formats are accepted. Outgoing payments, bills, arbitrary regex rules and nonpayment SMS are rejected.
- Requests use HTTPS, HMAC-SHA256, a fresh UUID nonce and a five-minute request timestamp. Redirects are rejected.
- Credentials and the receipt queue use AES-256-GCM with an Android Keystore key. Encryption failures stop the operation; there is no plaintext fallback. Cloud backup and device transfer are excluded.
- Queue writes are atomic. Delivery updates reload the current queue, preserving SMS captured during network requests. New triggers do not replace running workers.
- Completed history is capped at 100 receipts and seven days. Up to 1,000 unresolved receipts remain; capacity/storage failures produce an alert and do not evict unresolved receipts. Long-press a failed receipt to mark it handled after manual wallet/store review.
- Retries reset their attempt counter when requested manually. Network/server failures retry with backoff, while permanent errors need attention.
- The external portal, PIN backend, general SMS inbox, SMS sending/default-app role, arbitrary rules and unused dependencies have been removed.
- Release builds require your own signing key. The app ID is now `com.qabasic.smsforwarder`, so this installs separately from the original app.

Nagad is intentionally unsupported until receiving-wallet formats can be validated with real, redacted samples.

## Setup

Use a dedicated Android phone/SIM that receives SMS for the configured bKash wallet. The wallet number is provisioned by the operator; the app cannot independently prove SIM/wallet ownership. Do not use a phone with multiple bKash receiving accounts.

1. Configure the server receiver described in [docs/payment-protocol.md](docs/payment-protocol.md).
2. Install your signed APK, grant SMS and notification permissions, and open Home.
3. Set the exact HTTPS endpoint, device ID, receiving wallet number and the server's 64-character hexadecimal device secret.
4. Save delivery settings. The secret is stored in native encrypted storage and is never returned to Dart after saving. Leave it empty to keep the saved secret.
5. Allow background activity in Android battery settings. Optional foreground monitoring must be enabled while the app is visible. Android may time-limit dataSync services; SMS broadcasts and WorkManager remain the delivery mechanism.
6. Start with server automatic approval **off**. Compare accepted receipts with real wallet transactions before enabling it.
7. Use **Recover recent payment receipts** explicitly to recover eligible messages from the last 48 hours after an outage. This never imports unrelated inbox messages.

The old app and any old portal pairing are independent. Unpair/uninstall the original app after reviewing its outstanding transactions; this fork does not migrate or upload its old inbox.

## Development and tests

Requires Flutter 3.44.0 / Dart 3.12, Java 17+ and an Android SDK.

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --debug
cd android
./gradlew :app:testDebugUnitTest
```

On Windows use `gradlew.bat`. The debug APK is for testing only. No real phone/telecom tests are simulated by the JVM/Flutter tests.

## Release signing

Set these environment variables locally or as GitHub Actions secrets:

- `ANDROID_KEYSTORE_PATH`: absolute path to your private release keystore (local builds).
- `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
- `ANDROID_KEYSTORE_BASE64`: base64-encoded release keystore (GitHub Actions only).

Then run `flutter build apk --release`. Missing credentials fail the build; there is no fallback to debug signing. Keep signing keys and device secrets outside the repository. Tagged releases publish a signed APK; manually dispatched builds upload an artifact.

## Trust boundary

SMS sender labels are not cryptographic proof from bKash. HMAC authenticates the provisioned phone's report; it cannot protect against a compromised phone/SIM, a misconfigured receiving wallet or carrier-level SMS spoofing. Keep manual review, device monitoring and wallet reconciliation available. For independent provider confirmation, use an authorized merchant payment API.

Android cryptography follows [Android's cryptography guidance](https://developer.android.com/privacy-and-security/cryptography).
