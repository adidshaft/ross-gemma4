# Ross Real Local Inference Adapter Alpha Report

## Branch

- Working branch: `alpha-real-local-inference`
- Base branch preserved: `alpha-local-model-extraction`

## Scope completed

This phase moves Ross from a runtime contract plus deterministic development provider toward a real local inference adapter alpha.

What is now true:

- the deterministic development provider remains intact for CI and fallback
- runtime metadata can represent real local runtime modes
- prompt packing exists
- schema validation exists
- verifier gating remains strict
- Android and iOS both select real-or-fallback providers behind the installed-pack abstraction
- iOS has one real local adapter path behind explicit developer opt-in

What is not yet true:

- no large model file is committed or bundled
- Android does not yet execute a real local model in this branch
- no real local model execution was validated in the final matrix because no developer-provided model runtime was supplied during this run

## Implemented in this phase

### Shared and Rust core

- added runtime metadata for:
  - `LocalRuntimeMode`
  - `LocalModelArtifactKind`
  - `LocalRuntimeHealth`
  - `LocalModelResourceEstimate`
  - `ModelPromptPolicy`
- extended `LocalModelProvider` with:
  - availability and runtime-mode reporting
  - context-window and input-budget estimates
  - runtime health
  - optional streaming hook
- added `PromptPackBuilder`
- added schema-specific output validation helpers
- added verifier disposition helpers for:
  - `verified`
  - `needs_review`
  - `rejected`
- added `EvaluationRun` regression reporting

### Android

- added runtime metadata and prompt-packing support to the Android local runtime layer
- added compile-safe real-provider scaffolding for:
  - `mediapipe_llm`
  - `gemma_local_runtime`
- added debug configuration support for:
  - `ROSS_ENABLE_REAL_LOCAL_INFERENCE`
  - `ROSS_LOCAL_RUNTIME`
  - `ROSS_LOCAL_MODEL_PATH`
- preserved deterministic fallback when a real adapter is unavailable
- persisted runtime mode in invocation metadata without persisting raw prompt or raw source text
- strengthened extracted-field public-law suggestion sanitization
- exposed technical runtime details only inside Private AI technical details

### iOS

- added runtime metadata and prompt-packing support to the iOS local runtime layer
- added a real Apple Foundation Models adapter path behind availability checks
- made real-runtime probing explicit so CI and simulator tests stay deterministic unless a developer opts in
- preserved deterministic fallback when the real runtime is unavailable
- persisted runtime mode in invocation metadata without persisting raw prompt or raw source text
- strengthened extracted-field public-law suggestion sanitization
- exposed technical runtime details only inside Private AI technical details

### Backend

- widened runtime and artifact metadata enums to support:
  - `deterministic_dev`
  - `mediapipe_llm`
  - `gemma_local_runtime`
  - `apple_foundation_models`
  - `unavailable`
  - `tiny_dev_artifact`
  - `local_model_artifact`
  - `system_model`
  - `external_debug_model`
- added `minimumAppVersion` metadata to catalog and download payloads
- kept actual delivered artifacts as tiny deterministic development artifacts only

### Documentation

- updated runtime, privacy, extraction, registry, offline-behavior, and product docs
- added `docs/MANUAL_LOCAL_INFERENCE_QA.md`
- documented that deterministic development runtime is not a real LLM
- documented that real local inference requires explicit developer-provided local configuration in this alpha

## Real versus stubbed

### Real now

- deterministic development runtime
- prompt packing
- schema validation
- verifier/refiner categorization
- runtime health and resource estimates
- real-or-fallback provider selection
- iOS Apple Foundation Models adapter path

### Still stubbed

- Android real local inference execution
- MediaPipe integration on either platform
- Gemma 4 Q4 runtime integration on either platform
- production pack delivery of large local model artifacts

## Baseline validation before edits

These all passed before any code changes:

- Rust: `cargo test`
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

These all passed after implementation:

- Rust: `cargo test`
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

## Backend smoke

Live backend smoke passed against a locally started built server on port `8091`.

Port `8080` was already occupied on this machine, so the smoke was rerun on `8091` without changing backend code.

Validated:

- `GET /model-catalog`
- `POST /model-download/session`
- `GET /dev-artifacts/:artifactId` with `Range`
- `POST /public-law/search`

Observed smoke payload state:

- catalog `artifactKind`: `tiny_dev_artifact`
- catalog `runtimeMode`: `deterministic_dev`
- catalog `minimumAppVersion`: `null`
- download session `artifactKind`: `tiny_dev_artifact`
- download session `runtimeMode`: `deterministic_dev`
- download session `minimumAppVersion`: `null`
- ranged artifact download returned `206`
- sanitized public-law search returned `200`

## Privacy status

- no cloud model calls were added
- no cloud OCR was added
- no analytics or telemetry SDKs were added
- raw prompts are not persisted by default
- raw source text is not persisted in invocation metadata by default
- invocation metadata uses hashes and redacted source refs
- public-law suggestions now use verified or user-corrected legal concepts only

## Manual real-runtime status

- Real local inference adapter implemented: `Yes`
- Real local inference actually ran during this validation pass: `No`
- Runtime mode exercised in final validation: `deterministic_dev`

To manually exercise the real iOS path in a future run:

- set `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- set `ROSS_LOCAL_RUNTIME=apple_foundation_models`
- optionally set `ROSS_LOCAL_MODEL_PATH=/absolute/path/to/local/model` if an external adapter file is required
- run the manual QA flow in `docs/MANUAL_LOCAL_INFERENCE_QA.md`

## Repository hygiene

- `SCRIPT.md` was inspected and left untouched
- `artifacts/` was inspected and left untouched
- neither was modified or committed

## Exact next recommended step

Implement one production-grade real Android adapter path for `Case Associate`, preferably MediaPipe local inference if it compiles reliably in this environment, and run a manual end-to-end extraction on a developer-provided local artifact so Ross can validate true on-device extraction, verification, and review behavior outside the deterministic fallback path.
