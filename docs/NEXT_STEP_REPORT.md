# Ross Real Local Model Proof & QA Alpha Report

## Branch

- Base branch inspected: `alpha-real-device-inference`
- Working branch created successfully: `alpha-real-model-proof`

## Scope completed

This phase focused on proving and productizing the real local model path without weakening Ross's privacy boundary or destabilizing deterministic CI behavior.

What is now true:

- Android is ready for physical-device `mediapipe_llm` proof with a developer-provided `.task` artifact.
- Android runtime health can distinguish:
  - deterministic dev runtime
  - real local runtime available
  - real local runtime unavailable
  - fallback active
- Backend can advertise external debug-model metadata in explicit dev mode.
- Backend can optionally serve a developer-provided external model artifact in explicit dev mode with range support and path safety checks.
- Case Associate extraction still routes through prompt packing, schema validation, source validation, and verifier gating before any output is accepted.
- Low-confidence or unsupported fields are not silently accepted.
- Android now records local-only inference metrics without storing raw prompt text, raw source text, or raw model output.
- Public-law suggestion generation remains limited to verified or user-corrected legal concepts and strips private facts before backend submission.

What is still not proven in this environment:

- No real Android model execution occurred because no physical Android device was attached and no developer-provided `.task` artifact was available to this session.
- No real iOS runtime execution occurred because no compatible device/runtime was available to this session.

## Model artifact strategy

Alpha recommendation implemented in docs:

- Preferred first proof path: developer-provided local debug model on device via `ROSS_LOCAL_MODEL_PATH`
- Optional metadata path: backend-advertised `external_debug_model`, disabled by default
- Optional serving path: backend-served external dev artifact from an absolute path outside the repo, disabled by default
- Production delivery remains future work:
  - signed manifests
  - checksums
  - app-private storage
  - no bundled model files

## Backend status

Implemented:

- explicit external model metadata env gate:
  - `ROSS_ENABLE_EXTERNAL_MODEL_METADATA=1`
  - `ROSS_EXTERNAL_MODEL_RUNTIME=mediapipe_llm`
  - `ROSS_EXTERNAL_MODEL_KIND=external_debug_model`
  - `ROSS_EXTERNAL_MODEL_SHA256`
  - `ROSS_EXTERNAL_MODEL_SIZE_BYTES`
  - `ROSS_EXTERNAL_MODEL_DISPLAY_NAME`
  - `ROSS_EXTERNAL_MODEL_MIN_APP_VERSION`
- explicit external model serving env gate:
  - `ROSS_ENABLE_EXTERNAL_MODEL_SERVING=1`
  - `ROSS_EXTERNAL_MODEL_FILE_PATH=<absolute path outside repo>`
- safe serving behavior:
  - disabled by default
  - rejects unsafe in-repo paths
  - verifies checksum and size
  - supports `Range`
  - does not expose raw local file paths in responses
  - does not accept case-data payloads
  - does not log fake-secret filenames or private content

## Android status

Implemented:

- strengthened real local model path validation:
  - missing model path
  - file existence
  - readability
  - bundled-asset rejection
  - optional checksum verification
- sanitized runtime error categories:
  - `missing_model_path`
  - `model_file_not_found`
  - `checksum_mismatch`
  - `unsupported_device`
  - `unsupported_runtime`
  - `invalid_model_output`
  - `runtime_dependency_unavailable`
  - `cancelled`
  - `unknown_runtime_error`
- technical details now show:
  - runtime mode
  - real runtime enabled
  - model path present
  - checksum verified
  - runtime available
  - fallback active
  - last runtime error category
  - last invocation runtime mode
- model paths remain redacted in normal UI:
  - only `Configured` or `Missing`
  - optional basename in technical debug section
- real-provider flow remains background-threaded and network-free
- large input is budgeted before real runtime use and fails safely
- fallback messaging makes it explicit that Ross used the available local extraction mode
- local-only inference metrics now exist for extraction evaluation and QA
- debug in-app smoke action exists under:
  - `Settings > Private AI > Technical details > Run local inference smoke`
- optional smoke helper script exists:
  - `/Users/amanpandey/projects/ross/scripts/dev/android-real-inference-smoke.sh`

Physical-device proof status:

- Ready for physical-device QA: `Yes`
- Actually ran real inference in this phase: `No`
- Exact blocker:
  - no connected physical Android device
  - no developer-provided `.task` artifact available to this session

## iOS status

Implemented:

- explicit opt-in real runtime remains gated by:
  - `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
  - `ROSS_LOCAL_RUNTIME=apple_foundation_models`
- technical details now expose sanitized runtime health and fallback state
- unavailable real runtime remains a safe fallback case
- debug in-app smoke action exists for explicit-opt-in compatible environments
- no raw prompt/source logging was added

Physical-device proof status:

- Ready for compatible-device QA: `Yes`
- Actually ran real inference in this phase: `No`
- Exact blocker:
  - no compatible Apple device/runtime available to this session

## Baseline validation before edits

These passed before implementation:

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

Additional observed notes:

- `swift test` passed with one long-running runtime-health redaction test at about 74 seconds.
- `xcodebuild` succeeded with existing device-label actor-isolation warnings in `DeviceCapabilityService.swift`; this phase did not alter that file.

## Backend live smoke

Ran against a locally started built server on port `4010`.

Validated:

- `GET /model-catalog?platform=android`
- `POST /model-download/session`
- `GET /dev-artifacts/:artifactId` with `Range: bytes=0-8191`
- `POST /public-law/search`

Observed results:

- catalog returned `artifactKind=tiny_dev_artifact`
- catalog returned `runtimeMode=deterministic_dev`
- download session returned `artifactKind=tiny_dev_artifact`
- download session returned `runtimeMode=deterministic_dev`
- ranged dev artifact request returned `206 Partial Content`
- first ranged segment SHA-256 matched the signed segment metadata
- sanitized public-law search returned `200`

Optional smokes not run:

- backend external model metadata smoke:
  - not run because external-model env vars were not configured in this session
- backend external model serving smoke:
  - not run against a real external file because explicit serving env vars were not configured in this session
- Android real-device smoke:
  - helper script dry-run performed
  - result: clean skip because no physical Android device was connected
- iOS real-device smoke:
  - not run because no compatible device/runtime was available

## Privacy status

- no cloud inference was added
- no cloud OCR was added
- no analytics SDKs were added
- no telemetry SDKs were added
- no large model files were committed
- no large model files were bundled in app assets
- raw prompts are not stored by default
- raw source text is not stored in model invocation metadata
- raw model output is not stored in local inference metrics
- runtime health and errors use sanitized categories
- public-law backend calls remain sanitized and preview-confirmed
- regression coverage now checks fake-secret leakage across:
  - backend logs
  - model delivery requests
  - public-law requests
  - local runtime metadata and metrics surfaces

## Repository hygiene

- `SCRIPT.md` was inspected and left untouched
- `artifacts/` was inspected and left untouched
- neither was modified or prepared for commit in this phase

## Remaining stubbed or blocked items

- honest real-device Android run result is still missing
- honest real-device iOS run result is still missing
- backend external model metadata and serving remain opt-in dev features and were not exercised here with a real external file
- local inference metrics currently exist on Android only; iOS readiness was limited to QA smoke/reporting and fallback clarity

## Exact next recommended step

Connect one physical Android device, provide one compatible developer `.task` artifact outside the repo, set:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- `ROSS_LOCAL_RUNTIME=mediapipe_llm`
- `ROSS_LOCAL_MODEL_PATH=<device or app-private model path>`
- optional: `ROSS_LOCAL_MODEL_CHECKSUM=<sha256>`

Then run:

- `/Users/amanpandey/projects/ross/scripts/dev/android-real-inference-smoke.sh`

After that, capture one honest `Case Associate` extraction in `docs/REAL_MODEL_QA_RESULTS.md` where:

- runtime mode is `mediapipe_llm`
- fallback active is `No`
- schema valid is `Yes`
- unsupported accepted count is `0`
- source refs are present
- export generation succeeds
- logs contain no raw prompt or source text
- no network model call occurs
