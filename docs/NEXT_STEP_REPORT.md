# Ross Android Real Local Inference Proof Report

## Branches

- Base branch inspected: `alpha-real-model-proof`
- Working branch created: `alpha-android-real-proof`

## Outcome

This phase did not prove a real Android local model run.

What is honest and verified:

- Android real local inference is still structurally ready for a physical-device `mediapipe_llm` proof.
- The repo stayed clean on the privacy boundary and passed the requested validation suite after one small iOS safety fix.
- The Android preflight remained blocked because there was no connected physical device and no developer-provided compatible `.task` artifact configured in this session.

## Exact Android blocker

- `adb devices -l` returned no connected devices.
- `scripts/dev/android-real-inference-smoke.sh` cleanly skipped with `Skipping: no physical Android device is connected.`
- No `ROSS_ENABLE_REAL_LOCAL_INFERENCE`, `ROSS_LOCAL_RUNTIME`, `ROSS_LOCAL_MODEL_PATH`, `ROSS_LOCAL_MODEL_CHECKSUM`, or `ROSS_LOCAL_MODEL_PUSH_SOURCE` environment variables were set in this session.
- No developer-provided `.task` artifact was supplied outside the repo for this phase.

Because of that, none of the following could be honestly claimed:

- runtime health on a physical Android device
- `mediapipe_llm` selected over `deterministic_dev`
- schema-valid real-device output
- source-backed field review on Android
- unsupported accepted count `0` from a real-device run
- export generation after a real Android model extraction
- on-device log review for prompt/source leakage
- on-device network verification that no model call left the device

## Baseline validation before edits

Passed before edits:

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
- Android: `./gradlew :app:testDebugUnitTest :app:assembleDebug`
- iOS:
  - `swift build --scratch-path tmp/swiftpm`
  - `xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/DerivedData build`

Blocked before edits:

- `swift test --scratch-path tmp/swiftpm` hung in `AlphaFoundationModelsLocalProvider.runtimeHealth()` because a missing configured adapter path still attempted to instantiate the Foundation Models adapter and blocked on a macOS system alert.

## Changes made

Code:

- iOS Foundation Models runtime-health probing now checks that a configured adapter path exists and is readable before touching the system runtime.
- Added a regression test that ensures a missing configured adapter path reports `runtime_dependency_unavailable` and keeps fallback active.

Docs:

- Updated the Android proof, runtime, privacy, and manual QA docs so they explicitly record that no real Android run happened in this session.
- Expanded the QA template to separate branch, commit, artifact details, fallback state, blocker state, and next exact manual step.

## Final validation after changes

Passed after changes:

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
- Android: `./gradlew :app:testDebugUnitTest :app:assembleDebug`
- iOS:
  - `swift build --scratch-path tmp/swiftpm`
  - `xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/DerivedData build`
  - `swift test --scratch-path tmp/swiftpm`
  - `swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`

Observed notes:

- Android emitted one existing Kotlin warning about an unchecked cast in `AlphaLocalModelRuntimeTest.kt`; the build still succeeded.
- `xcodebuild` succeeded. The previous blocking `swift test` hang is gone.

## Backend smoke

Live smoke passed on `http://127.0.0.1:4010` for:

- `GET /model-catalog?platform=android`
- `POST /model-download/session`
- `GET /dev-artifacts/:artifactId` with `Range`
- `POST /public-law/search`

Observed behavior:

- catalog runtime stayed `deterministic_dev`
- catalog artifact kind stayed `tiny_dev_artifact`
- model download runtime stayed `deterministic_dev`
- range request returned `206 Partial Content`
- ranged segment SHA-256 matched the signed metadata
- public-law search returned `200` with fixture-backed results

Optional external-model smoke also passed on `http://127.0.0.1:4011` using a safe temporary file outside the repo:

- external metadata appeared only when explicitly enabled
- external serving returned ranged bytes with a matching SHA-256
- neither catalog nor download responses exposed the backend file path

## iOS decision

iOS persisted `LocalInferenceMetrics` parity was deferred.

Reason:

- the phase goal is still an honest Android physical-device proof
- the only iOS change needed here was the missing-adapter safe-failure fix that restored validation reliability
- adding iOS metrics now would expand scope without helping prove Android `mediapipe_llm` on hardware

## Untracked items

These were inspected and intentionally left untouched:

- `SCRIPT.md`
- `artifacts/`

## Next exact step

1. Connect one physical Android device and confirm `adb devices -l` lists it as a real device, not an emulator.
2. Supply one compatible developer-provided `.task` model artifact outside the repo.
3. Set:
   - `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
   - `ROSS_LOCAL_RUNTIME=mediapipe_llm`
   - `ROSS_LOCAL_MODEL_PATH=<app-readable path on device>`
   - optional `ROSS_LOCAL_MODEL_CHECKSUM=<sha256>`
   - optional `ROSS_LOCAL_MODEL_PUSH_SOURCE=<absolute source path outside repo>`
4. Run `/Users/amanpandey/projects/ross/scripts/dev/android-real-inference-smoke.sh`.
5. Install and launch the Android debug APK.
6. In `Settings > Private AI > Technical details`, confirm:
   - real runtime enabled `yes`
   - runtime mode `mediapipe_llm`
   - model path `Configured`
   - checksum `verified` or `not configured`
   - runtime available `yes`
   - fallback active `no`
7. Run `Run local inference smoke`.
8. Complete one synthetic `Case Associate` extraction on the physical device and record the result in `docs/REAL_MODEL_QA_RESULTS.md`.
