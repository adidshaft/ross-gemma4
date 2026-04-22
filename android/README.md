# Ross Android

## Build and run

```bash
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

Open the Android project in Android Studio if you want emulator or device debugging.

## Current Android launch flow

The target internal-alpha flow is:

1. Language or welcome
2. Sign in or demo mode
3. Optional quick unlock where available
4. Home

The supported local QA path is `Open demo mode`.

## Sign-in modes

### Demo mode

- works without backend credentials
- creates a local session
- is for local testing only

### Google sign-in

- backend-mediated OAuth start flow is wired from the app
- custom callback route is `ross://auth/callback`
- Android deep link is registered in [`android/app/src/main/AndroidManifest.xml`](/Users/amanpandey/projects/ross/android/app/src/main/AndroidManifest.xml)

The current mobile flow uses backend-mediated OAuth rather than the native Google Android SDK, so Android SHA registration is not the main setup requirement in this phase. Real proof still depends on valid Google OAuth credentials on the backend side.

### Quick unlock

- Android checks `BiometricManager` with strong biometrics or device credential
- emulator behavior is limited
- physical-device proof is still required for a true manual claim

## Backend connectivity

Android resolves backend URLs in this order:

1. saved test-server override in Settings
2. `ROSS_BACKEND_BASE_URL`
3. system property override
4. build default from [`android/app/build.gradle.kts`](/Users/amanpandey/projects/ross/android/app/build.gradle.kts)

Default emulator address:

- `http://10.0.2.2:8080`

Recommended overrides:

- Android emulator with backend on `8787`: `http://10.0.2.2:8787`
- Physical Android device: `http://<your-mac-lan-ip>:8787`

You can save the address from `Settings > Advanced > Save test server`.

## Public-law search

- Web is off by default
- Web on still requires a local preview and explicit confirmation
- backend-unavailable errors should remain plain-language
- only a sanitized public-law query is sent

If the backend is configured with `ROSS_PUBLIC_LAW_GEMINI_API_KEY` or `GEMINI_API_KEY`, the confirmed public-law request is resolved server-side through Gemini with Google Search grounding.

If that key is missing, Ross falls back to privacy-safe fixture results and remains suitable for QA only.

## Private AI note

Normal Android screens should show plain-language status such as:

- `Ready`
- `Not installed`
- `Downloading`
- `Waiting for Wi-Fi`
- `Needs attention`
- `Using basic local mode`

Technical diagnostics stay under `Settings > Advanced`.

## Still unproven on Android

- real Google OAuth with real credentials
- physical-device quick unlock proof
- real local model proof on device

See [`docs/AUTH_QA.md`](/Users/amanpandey/projects/ross/docs/AUTH_QA.md) and [`docs/DEVICE_INSTALL_QA.md`](/Users/amanpandey/projects/ross/docs/DEVICE_INSTALL_QA.md).
