# Ross iOS Project

## Open and run in Xcode

1. Open `/Users/amanpandey/projects/ross/ios/Ross.xcodeproj` in Xcode.
2. Select the shared `Ross` scheme.
3. Pick any iOS Simulator destination.
4. Press Run.

The Xcode project reuses the existing SwiftUI sources in `/Users/amanpandey/projects/ross/ios/Ross` directly. `RossApp.swift` remains the app entry point for the iOS target.

## Command-line simulator build

From the repo root:

```sh
xcodebuild \
  -project ios/Ross.xcodeproj \
  -scheme Ross \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/tmp/DerivedData \
  build
```

If SwiftPM scratch data becomes corrupt locally, clear it and rerun:

```sh
cd /Users/amanpandey/projects/ross/ios
rm -rf tmp/swiftpm
swift build --scratch-path tmp/swiftpm
```

## SwiftPM tests

The local extraction orchestrator has a lightweight SwiftPM test target:

```sh
cd /Users/amanpandey/projects/ross/ios
swift test --scratch-path tmp/swiftpm
```

## Screenshot export

Screenshot export is a macOS-hosted Swift Package workflow, not an iOS Simulator workflow.

To export screenshots into `ios/tmp/ui-screenshots`, run from the `ios` directory:

```sh
cd /Users/amanpandey/projects/ross/ios
swift run Ross --generate-screenshots
```

## Current alpha foundation

- Active alpha state is encrypted at rest with Keychain-managed AES.GCM.
- Legacy plaintext state is migrated into encrypted storage on load.
- PDF imports index native page text locally where available.
- Image imports run local Vision OCR where available.
- iOS now runs a local extraction orchestrator in the active alpha shell:
  - PDF/text acquisition
  - language/script profiling
  - document classification
  - deterministic legal-field extraction fallback
  - local model-assisted extraction stubs
  - verification and review queue generation
- Source-backed extracted fields, extraction runs, findings, advocate corrections, and case-memory updates persist locally.
- The document workflow now includes `Review extracted details` with confidence badges, source chips, and accept/edit/ignore actions.
- Local exports are written as real PDF files under app-private storage, and generated PDFs can be shared through the system share sheet.
- Public-law search and model-download clients are compiled into the active alpha shell for a local backend at `http://127.0.0.1:8080`, with a local dev-artifact fallback for pack install if the backend is unavailable.

## Known caveats

- Exact text highlighting is still represented through source panels and page targeting rather than reliable per-snippet PDF selection overlays.
- The deeper local model passes are architected and stubbed, but this phase does not bundle full production model assets or a confirmed production on-device LLM runtime.
- Backend-connected mobile runtime flows still depend on a local development backend being available when you want to exercise the network boundary interactively.
- Fixture-driven tests validate the orchestrator contract, but they are not a proof of real-device inference quality.
