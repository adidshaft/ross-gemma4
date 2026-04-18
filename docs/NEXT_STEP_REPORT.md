# Ross Mobile Alpha Foundation Report

## Branch

- `alpha-mobile-foundation`

## What changed

- Added a checked-in Android Gradle wrapper and fixed the current Android build script issues so `:app:assembleDebug` works.
- Added a real iOS Xcode app project at `ios/Ross.xcodeproj` and wired the app entry to the new alpha foundation root.
- Added new Android and iOS alpha-foundation layers with:
  - typed route objects
  - file-backed local persistence for cases, documents, source refs, exports, model-pack jobs, installed packs, and privacy-ledger entries
  - document import into app-private storage
  - source-chip navigation into document viewer
  - basic local export generation
  - persisted Private AI Pack lifecycle state
- Hardened backend public-law query validation to reject obvious private matter content and the specified fake secrets without echoing them back.
- Updated platform runbooks and architecture docs for the new alpha behavior.

## Commands run

### Repository inspection

- `git status --short`
- `git log --oneline -n 8`
- Inspected `README.md`, product/privacy/model/legal docs, Android/iOS/backend/core/shared paths, `SCRIPT.md`, and `artifacts/`

### Rust core

- `cd core/rust && cargo test`

### Backend

- `cd backend && npm install`
- `cd backend && npm test`
- `cd backend && npm run typecheck`
- `cd backend && npm run build`

### Privacy guards

- `./scripts/dev/verify-boundaries.sh`
- `./scripts/ci/check-no-cloud-llm.sh`
- `./scripts/ci/check-no-analytics.sh`
- `./scripts/ci/check-no-large-model-assets.sh`
- `./scripts/ci/check-onboarding-copy-boundary.sh`

### Android

- `/Users/amanpandey/.gradle/wrapper/dists/gradle-8.14.3-bin/cv11ve7ro1n3o1j4so8xd9n66/gradle-8.14.3/bin/gradle -p android wrapper --gradle-version 8.14.3`
- `cd android && ./gradlew :app:assembleDebug`
- `cd android && ./gradlew :app:testDebugUnitTest :app:assembleDebug`

### iOS

- `cd ios && swift build`
- `cd ios && swift build --scratch-path tmp/swiftpm`
- `xcodebuild -project ios/Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/tmp/DerivedData build`
- `cd ios && swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`

## Pass / fail status

### Passed

- Rust tests
- Backend tests
- Backend typecheck
- Backend build
- Privacy guard scripts
- Android `:app:assembleDebug`
- Android `:app:testDebugUnitTest`
- iOS simulator build through `xcodebuild`
- Screenshot export through `swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`

### Build failures encountered and resolved

- Android wrapper generation initially failed because `android/app/build.gradle.kts` still used `kotlinOptions.jvmTarget = "17"`. Fixed by migrating to the current Kotlin compiler DSL.
- Android `:app:assembleDebug` then failed because the XML theme referenced `Theme.Material3.DayNight.NoActionBar` without the Material dependency on the classpath. Fixed by adding `com.google.android.material:material`.
- Android compile then failed on an experimental Material API use in `WorkbenchScreen`. Fixed with the required `@OptIn(ExperimentalMaterial3Api::class)`.
- `swift build` on the package path intermittently failed with a local SwiftPM build-database disk I/O error under `.build`. The package compiled successfully when redirected to `--scratch-path tmp/swiftpm`.
- The first iOS simulator build failed because the new `AlphaFoundation` files had been added to the Xcode project with the wrong path. Fixed by correcting the file references in `ios/Ross.xcodeproj/project.pbxproj`.

## Privacy guard status

- `verify-boundaries.sh`: passed
- `check-no-cloud-llm.sh`: passed
- `check-no-analytics.sh`: passed
- `check-no-large-model-assets.sh`: passed
- `check-onboarding-copy-boundary.sh`: passed

## What builds now

- Android app from CLI through the checked-in Gradle wrapper
- Android unit tests
- iOS app for simulator through `ios/Ross.xcodeproj`
- iOS screenshot export through the Swift package path

## Remaining gaps and stubs

- Android document viewing is still MVP-level and placeholder-heavy for PDF page rendering.
- iOS document viewing uses a real PDF preview path, but precise snippet highlighting is still represented through source-reference panels rather than exact text highlights.
- OCR remains interface/placeholder level where platform OCR is not yet wired.
- Mobile public-law search stays privacy-safe and explicit, but the current mobile results are still stub-backed rather than running a true backend-connected in-app search flow.
- Model-pack lifecycle is now persisted and checksum-aware, but the installed artifact is still a small local development artifact rather than a real segmented model payload.
- Real encrypted persistence, real local model inference, and a full export PDF renderer remain future steps.

## Manual next steps if a developer machine differs

- If Android Studio does not have the required SDK/toolchain, open `/Users/amanpandey/projects/ross/android`, let it sync via the checked-in wrapper, and install any requested SDK components.
- If SwiftPM hits a local `.build` database issue, use `cd /Users/amanpandey/projects/ross/ios && swift build --scratch-path tmp/swiftpm`.
- To run the iOS app interactively, open `/Users/amanpandey/projects/ross/ios/Ross.xcodeproj`, select the shared `Ross` scheme, and run it on any iOS Simulator.
