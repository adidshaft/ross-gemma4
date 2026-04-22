# Ross Android

## Build and run

```bash
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
./gradlew :app:installDebug
```

Open the Android project in Android Studio if you want emulator or device debugging.

## Current Android launch flow

The intended lawyer-facing flow is:

1. Welcome or language entry
2. Sign in or demo mode
3. Optional quick unlock where available
4. Home

The supported local QA path is `Open demo mode`.

## Demo mode

Demo mode:

- works without backend credentials
- creates a local session
- seeds a synthetic workspace for QA
- is for local testing only

Reset path:

- `Settings > Account > Reset demo data`

## Sign-in modes

### Google sign-in

- backend-mediated OAuth start flow is wired
- callback route is `ross://auth/callback`
- Android deep link remains registered in [`android/app/src/main/AndroidManifest.xml`](/Users/amanpandey/projects/ross/android/app/src/main/AndroidManifest.xml)

The mobile flow is backend-mediated rather than native Google SDK based. Real proof still depends on valid backend credentials and a manual run.

### Quick unlock

- Android checks `BiometricManager` with strong biometrics or device credential
- emulator behavior is limited
- physical-device proof is still required for a real manual claim

## Backend connectivity

Android resolves backend URLs in this order:

1. saved test-server override in Settings
2. `ROSS_BACKEND_BASE_URL`
3. system property override
4. build default from [`android/app/build.gradle.kts`](/Users/amanpandey/projects/ross/android/app/build.gradle.kts)

Default emulator address:

- `http://10.0.2.2:8080`

Recommended overrides:

- Android emulator with backend on `8081`: `http://10.0.2.2:8081`
- physical Android device: `http://<your-mac-lan-ip>:8081`

## Public-law search

- `Web search` is off by default
- enabling `Web search` still requires a local preview and explicit confirmation
- only the approved sanitized public-law query is sent
- backend-unavailable errors should remain plain-language

Legal citations preserved by tests include:

- `Order 39 Rules 1 and 2 CPC`
- `Section 138 NI Act`
- `Section 482 CrPC`

If the backend is configured with `ROSS_PUBLIC_LAW_GEMINI_API_KEY` or `GEMINI_API_KEY`, the confirmed public-law request is resolved server-side through Gemini with Google Search grounding.

If that connector is unavailable, Ross falls back to a privacy-safe backend index for QA.

## Current Android truth on April 23, 2026

Fresh manual environment proof in this pass:

- local `Pixel_8` emulator booted successfully
- debug APK installed successfully with `./gradlew :app:installDebug`

Fresh blocker in this pass:

- the installed app does not launch through `adb`
- `adb shell am start -W -n com.ross.android/com.ross.android.MainActivity` returns `Error type 3`
- `adb shell dumpsys package com.ross.android` still lists `MainActivity` as the `MAIN` / `LAUNCHER` activity

Current consequence:

- no fresh Android in-app walkthrough was completed in this pass
- dock persistence, document flow, public-law preview/results, exports, ledger, and Settings still need Android manual proof after the launch blocker is resolved

See [`docs/PRODUCT_PROOF_QA.md`](/Users/amanpandey/projects/ross/docs/PRODUCT_PROOF_QA.md), [`docs/AUTH_QA.md`](/Users/amanpandey/projects/ross/docs/AUTH_QA.md), and [`docs/REAL_WORLD_USAGE_QA.md`](/Users/amanpandey/projects/ross/docs/REAL_WORLD_USAGE_QA.md).
