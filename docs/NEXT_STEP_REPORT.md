# Ross Real Device Local Inference Proof Alpha Report

## Branch

- Working branch: `alpha-real-device-inference`
- Base branch preserved: `alpha-real-local-inference`

## Scope completed

This phase focused on proving a concrete local inference path without weakening privacy, deterministic fallback, or CI stability.

What is now true:

- canonical debug configuration names are normalized across Android, iOS, and docs
- Android has a concrete real local inference adapter path for developer-supplied model artifacts
- Android runtime selection can distinguish deterministic, real local, unavailable, and fallback-active states
- iOS keeps the Foundation Models path behind explicit opt-in with safer health reporting and fallback behavior
- Case Associate output still flows through prompt packing, JSON extraction, schema validation, source validation, verifier gating, and advocate review
- deterministic development runtime remains the CI default and the safety fallback
- verified-field public-law suggestions are hardened to avoid private facts

What is not yet true:

- no real Android model execution was validated in this environment because no physical Android device and compatible developer model artifact were provided
- no real iOS Foundation Models execution was validated in this environment because no compatible Apple Intelligence device/runtime was available here
- backend delivery still serves tiny deterministic development artifacts only

## Implemented in this phase

### Shared behavior

- normalized canonical debug configuration names:
  - `ROSS_BACKEND_BASE_URL`
  - `ROSS_ENABLE_REAL_LOCAL_INFERENCE`
  - `ROSS_LOCAL_RUNTIME`
  - `ROSS_LOCAL_MODEL_PATH`
  - `ROSS_LOCAL_MODEL_CHECKSUM`
  - `ROSS_LOCAL_MODEL_KIND`
- kept `ROSS_BACKEND_URL` as a legacy alias only where needed for compatibility
- preserved deterministic fallback when real runtime is unavailable or unsafe
- continued to avoid raw prompt persistence and raw source-text persistence in invocation metadata

### Android

- added a concrete `AlphaMediaPipeLocalModelProvider`
- added the MediaPipe GenAI dependency behind the provider boundary
- supported model loading from:
  - canonical debug model path
  - supported installed-pack artifact paths
  - app-private imported paths
- added sanitized real-runtime health reporting:
  - runtime mode
  - fallback active
  - explicit opt-in enabled
  - model path present
  - checksum verified
  - last runtime error category
  - last invocation runtime
- added safe error categories instead of leaking raw runtime failures
- kept the provider off the main thread and away from network imports
- added batching and input-budget enforcement for extraction, issue extraction, classification, and verification passes

### iOS

- refined canonical runtime configuration parsing for the explicit opt-in Foundation Models path
- preserved explicit opt-in behavior for `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- required `ROSS_LOCAL_RUNTIME=apple_foundation_models` for the system-model path
- added safer runtime health reporting with fallback and unavailability reasons
- sanitized runtime failures and invalid output handling
- preserved deterministic fallback in CI and simulator environments

### Public-law suggestions

- restricted public-law previews to verified or user-corrected legal concepts
- stripped fake secrets, emails, phone numbers, case-like identifiers, and private-date-like fragments from preview candidates
- preserved preview confirmation as mandatory before backend search

### QA and docs

- added `docs/ANDROID_REAL_INFERENCE_QA.md`
- added `docs/RUNTIME_DECISION_MEMO.md`
- added `docs/MANUAL_CASE_ASSOCIATE_E2E.md`
- updated local runtime, privacy, offline, extraction, registry, product, Android, and iOS docs
- added `scripts/dev/run-local-inference-smoke.sh`

## Android adapter status

- Android real local inference adapter status: `Concrete`
- Selected real runtime path: `MediaPipe local model provider via developer-supplied external or app-private model artifact`
- Required artifact policy:
  - model file is developer-provided
  - model file is not committed to git
  - model file is not bundled in app assets
- Real Android local inference actually ran in this phase: `No`

## iOS adapter status

- iOS real local inference path status: `Explicit opt-in Foundation Models adapter preserved and refined`
- Selected real runtime path: `apple_foundation_models`
- Compatible device and runtime still required for real execution
- Real iOS local inference actually ran in this phase: `No`

## Baseline validation before edits

These passed before code changes:

- Rust:
  - `cargo test`
- Backend:
  - `npm test`
  - `npm run typecheck`
  - `npm run build`
- Privacy guards:
  - `./scripts/dev/verify-boundaries.sh`
  - `./scripts/ci/check-no-cloud-llm.sh`
  - `./scripts/ci/check-no-analytics.sh`
  - `./scripts/ci/check-no-large-model-assets.sh`
  - `./scripts/ci/check-onboarding-copy-boundary.sh`
- Android:
  - `./gradlew :app:testDebugUnitTest :app:assembleDebug`
- iOS:
  - `swift build --scratch-path tmp/swiftpm`
  - `xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/DerivedData build`
  - `swift test --scratch-path tmp/swiftpm`
  - `swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`

## Final validation after changes

These passed after implementation:

- Rust:
  - `cargo test`
- Backend:
  - `npm test`
  - `npm run typecheck`
  - `npm run build`
- Privacy guards:
  - `./scripts/dev/verify-boundaries.sh`
  - `./scripts/ci/check-no-cloud-llm.sh`
  - `./scripts/ci/check-no-analytics.sh`
  - `./scripts/ci/check-no-large-model-assets.sh`
  - `./scripts/ci/check-onboarding-copy-boundary.sh`
- Android:
  - `./gradlew :app:testDebugUnitTest :app:assembleDebug`
- iOS:
  - `swift build --scratch-path tmp/swiftpm`
  - `xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/DerivedData build`
  - `swift test --scratch-path tmp/swiftpm`
  - `swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`
- Local smoke helper:
  - `scripts/dev/run-local-inference-smoke.sh`
  - deterministic smoke passed
  - real-runtime smoke skipped cleanly when no developer model path was configured

## Backend smoke

Backend smoke passed against a locally started built server on port `8091`.

Validated:

- `GET /model-catalog`
- `POST /model-download/session`
- `GET /dev-artifacts/:artifactId` with `Range`
- `POST /public-law/search`

Observed results:

- catalog response returned `artifactKind=tiny_dev_artifact`
- catalog response returned `runtimeMode=deterministic_dev`
- download session response returned `artifactKind=tiny_dev_artifact`
- download session response returned `runtimeMode=deterministic_dev`
- ranged dev artifact request returned `206 Partial Content`
- sanitized public-law search returned `200`

## Privacy status

- no cloud inference was added
- no cloud OCR was added
- no analytics or telemetry SDKs were added
- raw prompts are not persisted by default
- raw source text is not stored in invocation metadata
- runtime health surfaces use sanitized error categories
- fake-secret regression coverage protects backend and public-law payload boundaries

## Repository hygiene

- `SCRIPT.md` was inspected and left untouched
- `artifacts/` was inspected and left untouched
- neither is to be committed as part of this phase

## Exact next recommended step

Run the Android manual physical-device QA flow with a compatible developer-provided `.task` model artifact and `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`, then capture one real `Case Associate` extraction where runtime health shows real availability, invocation metadata records a non-deterministic runtime mode, schema validation passes, source chips render, Privacy Ledger shows no model-network event, and logs contain no raw prompt or source text.
