# Ross Private Document Intelligence Alpha Report

## Branch

- Started from `alpha-mobile-foundation`
- Continued work on new branch `alpha-document-intelligence`

## Commands run

### Repository inspection

- `git status --short`
- `git log --oneline -n 8`
- Inspected active alpha shell paths, backend routes/tests, `SCRIPT.md`, and `artifacts/`

### Baseline validation run before changes

- `cd /Users/amanpandey/projects/ross/core/rust && cargo test`
- `cd /Users/amanpandey/projects/ross/backend && npm install`
- `cd /Users/amanpandey/projects/ross/backend && npm test`
- `cd /Users/amanpandey/projects/ross/backend && npm run typecheck`
- `cd /Users/amanpandey/projects/ross/backend && npm run build`
- `cd /Users/amanpandey/projects/ross && ./scripts/dev/verify-boundaries.sh`
- `cd /Users/amanpandey/projects/ross && ./scripts/ci/check-no-cloud-llm.sh`
- `cd /Users/amanpandey/projects/ross && ./scripts/ci/check-no-analytics.sh`
- `cd /Users/amanpandey/projects/ross && ./scripts/ci/check-no-large-model-assets.sh`
- `cd /Users/amanpandey/projects/ross && ./scripts/ci/check-onboarding-copy-boundary.sh`
- `cd /Users/amanpandey/projects/ross/android && ./gradlew :app:testDebugUnitTest :app:assembleDebug`
- `cd /Users/amanpandey/projects/ross/ios && swift build --scratch-path tmp/swiftpm`
- `cd /Users/amanpandey/projects/ross/ios && xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/DerivedData build`
- `cd /Users/amanpandey/projects/ross/ios && swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`

### Final validation run after changes

- `cd /Users/amanpandey/projects/ross/core/rust && cargo test`
- `cd /Users/amanpandey/projects/ross/backend && npm test`
- `cd /Users/amanpandey/projects/ross/backend && npm run typecheck`
- `cd /Users/amanpandey/projects/ross/backend && npm run build`
- `cd /Users/amanpandey/projects/ross && ./scripts/dev/verify-boundaries.sh`
- `cd /Users/amanpandey/projects/ross && ./scripts/ci/check-no-cloud-llm.sh`
- `cd /Users/amanpandey/projects/ross && ./scripts/ci/check-no-analytics.sh`
- `cd /Users/amanpandey/projects/ross && ./scripts/ci/check-no-large-model-assets.sh`
- `cd /Users/amanpandey/projects/ross && ./scripts/ci/check-onboarding-copy-boundary.sh`
- `cd /Users/amanpandey/projects/ross/android && ./gradlew :app:testDebugUnitTest :app:assembleDebug`
- `cd /Users/amanpandey/projects/ross/ios && rm -rf tmp/swiftpm && swift build --scratch-path tmp/swiftpm`
- `cd /Users/amanpandey/projects/ross/ios && xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/DerivedData build`
- `cd /Users/amanpandey/projects/ross/ios && swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`

## Pass / fail status

- Rust: passed
- Backend tests: passed
- Backend typecheck: passed
- Backend build: passed
- Privacy guards: passed
- Android unit tests and debug assemble: passed
- iOS simulator build: passed
- iOS screenshot export: passed

## Platform status

### Android

- Encrypted app-private persistence now wraps the active alpha state store and migrates legacy plaintext `state.json` into encrypted `state.enc`
- Local PDF export now writes real PDF files under app-private storage
- Source-chip routing now resolves page-targeted source panels and safe missing-source handling
- PDF preview uses `PdfRenderer` for in-app page preview
- Model catalog/download payload shapers and checksum-guarded dev pack install plumbing are covered by unit tests

### iOS

- Encrypted app-private persistence now wraps the active alpha store and migrates legacy plaintext state into AES.GCM-encrypted state blobs
- PDF imports now index native PDF text page-by-page through PDFKit where present
- Image imports now run local Vision text recognition where available
- Document viewer now accepts initial page targeting and shows source-reference context
- Local export generation now writes real PDF files instead of plain text
- Public-law and model-download backend clients now compile into the active alpha shell, with local dev-artifact fallback if the backend is unavailable

### Backend

- `/model-catalog` now returns signed tiny dev-artifact metadata with checksum, segment size, and segment count
- `/model-download/session` now returns signed segmented download metadata with `downloadPath`
- `/dev-artifacts/:artifactId` now serves real tiny dev artifacts with byte-range support for resumable development downloads
- `/public-law/search` returns sanitized fixture-index results and logs only hashed query metadata on rejection/production flows

## Screenshots

- Regenerated under `/Users/amanpandey/projects/ross/ios/tmp/ui-screenshots`
- `ios-onboarding.png`
- `ios-private-ai-pack.png`
- `ios-workspace.png`
- `ios-ask-case.png`

## Remaining stubs

- Android active alpha shell still uses local dev/stub behavior for public-law execution and model-download execution; only the privacy-safe payload shaping, checksum plumbing, and persistence/tests are fully landed there
- Android image OCR through on-device ML Kit is not wired yet
- Android PDF text extraction remains page-record and preview oriented rather than true text extraction
- Exact snippet highlighting is still best-effort source-panel UX on both platforms rather than precise text selection overlays
- iOS backend-connected public-law/model-download paths compile and can run against a local backend, but they were not exercised end-to-end against a live mobile simulator session in this turn
- Share-sheet/FileProvider export sharing is not wired yet; exports are generated locally and persisted safely

## Environment notes

- `swift build --scratch-path tmp/swiftpm` succeeded after clearing the generated scratch directory once; the earlier failure mode was a local SwiftPM build-database disk I/O error inside `tmp/swiftpm/build.db`
- No live backend server was launched for simulator/device interaction during this turn, so mobile-to-backend runtime flows were validated by build/test coverage and backend endpoint tests rather than full interactive end-to-end sessions

## Exact next recommended step

- Wire the Android alpha shell to the hardened backend endpoints with background-safe clients for `/model-catalog`, `/model-download/session`, `/dev-artifacts/:artifactId`, and `/public-law/search`, then add on-device ML Kit OCR for imported images so both mobile platforms reach the same functional document-intelligence baseline.
