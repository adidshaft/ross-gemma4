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
- Cases, documents, source refs, privacy ledger entries, exports, and model-pack jobs persist to encrypted app-private storage metadata under the app files directory.
- PDF, image, and text imports are copied into app-private storage.
- Source chips deep-link into the document viewer with page-targeted source panels and safe missing-source handling.
- Local exports are written as real PDF files in app-private storage.
- Public-law search stays on a sanitized-preview flow and only uses local alpha execution right now.

## Known caveats

- Android document viewing is MVP-level: it shows metadata, extracted text, source-reference panels, and PDF previews, but exact snippet highlighting is still best-effort only.
- Model-pack lifecycle is operational at the state-machine level with checksum plumbing, encrypted persistence, and app-private artifacts, but runtime backend execution is still pending in the active alpha shell.
- Android image OCR via on-device ML Kit and deeper PDF text extraction are still the next implementation step.
