# Ross Android Project

## Build from CLI

From the repo root:

```sh
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
```

To run the current JVM tests:

```sh
cd /Users/amanpandey/projects/ross/android
./gradlew :app:testDebugUnitTest
```

## Open in Android Studio

1. Open `/Users/amanpandey/projects/ross/android` as the project root.
2. Let Android Studio use the checked-in Gradle wrapper.
3. Sync the project.
4. Run the `app` configuration on an emulator or attached device.

The Android package namespace remains `com.ross.android`.

## Current alpha foundation

- Onboarding flows into Private AI Pack setup and then the case list.
- Cases, documents, source refs, privacy ledger entries, exports, and model-pack jobs persist to app-private JSON storage under the app files directory.
- PDF, image, and text imports are copied into app-private storage.
- Source chips deep-link into the document viewer.
- Public-law search stays on a sanitized-preview flow and only uses stub preview results locally right now.

## Known caveats

- Android document viewing is MVP-level: it shows metadata, extracted text, and source-reference panels, but PDF page rendering is still placeholder-based.
- Model-pack lifecycle is operational at the state-machine level with checksum plumbing and app-private artifacts, but the actual download/install uses a development artifact rather than a real large pack.
- Public-law search is privacy-safe and explicit, but still stub-backed on the mobile side until the backend/stub environment is connected in-device.
