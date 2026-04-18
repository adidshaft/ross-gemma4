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
- Cases, documents, source refs, extracted fields, extraction runs, findings, case memory updates, exports, and model-pack jobs persist to encrypted app-private storage.
- PDF, image, and text imports are copied into app-private storage.
- Android now runs a local extraction orchestrator in the active alpha shell:
  - PDF page rendering
  - on-device ML Kit OCR
  - language/script heuristics
  - deterministic legal-field fallback
  - local model-assisted extraction stubs by pack capability
  - verifier/review queue generation
- Source chips deep-link into the document viewer with page-targeted source panels.
- The document workflow now includes a practical `Review extracted details` surface with confidence badges and accept/edit/ignore actions.
- Local exports are written as real PDF files in app-private storage.
- Public-law search keeps the sanitized-preview flow and uses the hardened backend route when available.
- Model-pack delivery uses `/model-catalog`, `/model-download/session`, and `/dev-artifacts/:artifactId` with checksum verification and local fallback behavior for development.

## Known caveats

- Android document viewing is still MVP-level for exact highlights: page targeting and source chips are reliable, but precise snippet overlays remain best-effort.
- The deeper local LLM-assisted extraction and verifier passes are represented by orchestration interfaces and stubs rather than a full production local model runtime in this phase.
- PDF text acquisition on Android is still centered on rendered pages plus OCR; it is not yet as mature as the iOS native PDF text path for mixed bundles.
