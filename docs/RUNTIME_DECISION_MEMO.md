# Runtime Decision Memo

## Current status

- Android now has a concrete MediaPipe local inference adapter path for `Case Associate` and related extraction passes.
- The Android adapter compiles against `com.google.mediapipe:tasks-genai:0.10.27`.
- The Android adapter loads only developer-provided `.task` model files from debug or app-private storage.
- iOS keeps the Apple Foundation Models path behind explicit opt-in.
- Deterministic development runtime remains the default for CI, simulator, and safe fallback.
- No model file is committed to this repo.
- No cloud inference is used.

## Runtime paths chosen

### Android

- Chosen runtime: `mediapipe_llm`
- Input artifact: developer-provided `.task` file
- Load locations:
  - `ROSS_LOCAL_MODEL_PATH` in debug/manual flows
  - installed-pack path when the pack metadata uses `local_model_artifact` or `external_debug_model`
  - app-private imported path resolved under the Ross app storage root
- Output handling:
  - bounded prompt packing
  - JSON candidate extraction
  - schema validation
  - source-ref validation
  - verifier/refiner gating
  - advocate review

### iOS

- Chosen runtime: `apple_foundation_models`
- Availability: explicit opt-in only
- Use only on compatible Apple Intelligence hardware and OS
- Deterministic fallback remains the default when opt-in is absent or runtime availability is false

## What CI actually validates

- Rust deterministic extraction and privacy tests
- Backend tests, typecheck, build, and smoke-safe routes
- Privacy boundary guard scripts
- Android unit tests and `assembleDebug`
- iOS Swift package build/tests, Xcode simulator build, and screenshot export

CI does not validate a real model execution.

## What requires a physical device

- Android MediaPipe real runtime execution
- iOS Apple Foundation Models execution on compatible hardware
- Thermal, memory, and latency observation under a non-simulator workload

## What requires a developer model artifact

- Android real runtime execution
- Android checksum validation against a real local model
- Any claim that `mediapipe_llm` actually ran

## What remains stubbed

- Android Gemma 4 Q4 runtime
- iOS MediaPipe and Gemma 4 Q4 adapters
- Production pack delivery for large real local model artifacts
- Any claim about production legal accuracy or broad Hindi quality

## Recommended alpha strategy

1. Keep deterministic development runtime as the default everywhere except deliberate manual QA.
2. Use Android MediaPipe as the first physical-device proof path because it can load a developer-supplied local artifact without bundling the model in the app.
3. Keep iOS Foundation Models behind explicit opt-in until a compatible device run is recorded.
4. Treat every real-runtime result as untrusted until it survives JSON extraction, schema validation, verifier checks, and advocate review.

## Risk register

- Model size: on-device artifacts can quickly become too large for normal app delivery and should stay outside Git and app bundles.
- Latency: first-token and total response time can be too slow for long pleadings.
- Thermal throttling: sustained extraction on a phone can reduce performance sharply.
- Memory: large prompt packs or large models can fail on mid-range devices.
- Output quality: legal extraction quality is still uncertain until physical-device runs are recorded.
- Hindi and mixed-language reliability: likely weaker than deterministic review for noisy bilingual filings until evaluated.
- Store package size: real local models should not ship inside Play Store or App Store binaries.
- Licensing: developer-supplied model artifacts must be reviewed before any production distribution plan.

## Go / no-go checklist for Case Associate alpha

- Go only if:
  - Android `mediapipe_llm` compiles and fallback stays deterministic in CI
  - manual Android QA confirms `Last invocation runtime` is `mediapipe_llm`
  - no model-network event appears in the Privacy Ledger
  - outputs remain schema-valid and source-backed
  - unsupported values land in `Needs advocate review` or are rejected

- No-go if:
  - the device path uses bundled assets or committed model files
  - runtime errors expose raw prompts or source text
  - public-law previews include party names, case numbers, or private facts
  - the app claims real inference without a verified device run
