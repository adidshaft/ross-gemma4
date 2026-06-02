# Real Model QA Results

## 2026-06-02 iOS simulator GGUF smoke

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`)
- Runtime mode: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Model SHA-256 observed locally: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- Whether model files were committed: No
- Whether real GGUF inference ran: Yes, in simulator, through `--local-model-smoke`
- Proof marker: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start`
- What passed:
  - English source-grounded answer about Article 417 citation verification
  - Bengali Bangla-script source-grounded answer
  - Hindi Devanagari source-grounded answer
  - general cautious answer without tagged sources
- Native model-vs-fallback marker: not recorded in this run. Later smoke logs include `bengali_native_model` and `hindi_native_model`; require those to be `true` before claiming native multilingual model behavior rather than product-safe source fallback behavior.
- What is still not proven:
  - physical iPhone download/resume/verify/activate of a multi-GB GGUF
  - physical-device imported PDF/image/text Ask flow and performance
  - separate embedding-model retrieval

## 2026-06-02 stricter iOS simulator GGUF smoke rerun

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`, `DCE8EAA3-A325-4FA9-A37B-C2653ECEDA6D`)
- Runtime mode: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Model SHA-256 observed locally: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- Smoke command shape: `xcrun simctl launch --terminate-running-process --console ... com.ross.ios --local-model-smoke` with `SIMCTL_CHILD_ROSS_*` environment variables and `ROSS_LOCAL_MODEL_SMOKE_STAGE_TIMEOUT_SECONDS=45`
- Result: passed.
- Proof marker: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start elapsed=91.00s source_raw_chars=339 source_parsed_chars=167 bengali_output_chars=171 hindi_output_chars=277 general_output_chars=283 source_native_model=true bengali_native_model=false hindi_native_model=true general_native_model=true`
- Observed behavior:
  - the smoke runner used the explicit environment-provided debug pack directly instead of loading persisted app state first
  - the simulator process loaded the GGUF metadata, constructed the llama.cpp context, and completed all four smoke stages
  - the app was manually terminated after the pass marker with `xcrun simctl terminate`
- Harness improvement made during this pass:
  - `--local-model-smoke` now emits flushed stage markers to stderr around debug-pack selection, provider resolution, and each provider call
  - each provider stage is guarded by a configurable timeout and returns a fail output if generation times out
  - direct environment-supplied GGUF smoke skips heavyweight persisted-state runtime-health loading before provider execution
- Current interpretation:
  - real GGUF simulator inference is proven for English source grounding, Hindi Devanagari output, general cautious output, and product-safe Bengali Bangla-script output
  - Bengali was kept safe by Ross's source-preserving fallback in this run (`bengali_native_model=false`), so native Bengali model generation is not yet proven
  - physical iPhone proof remains required before claiming downloaded-model performance or reliability over user-imported files

## 2026-04-24 Gemma 4 metadata update

- Branch: `gemma-4-gguf-model-strategy`
- Quick Start metadata: Gemma 4 E2B Q4
- Case Associate metadata: Gemma 4 E4B Q4
- Senior Drafting Support metadata: Gemma 4 26B-A4B Q4
- Retrieval metadata: separate Matter Search embedding model
- Backend default: tiny deterministic artifacts
- Backend production metadata mode: Gemma 4 metadata only, no real download session
- Whether model files were committed: No
- Whether real Gemma 4 Q4 inference ran: Not in this historical April pass. A later June 2 simulator GGUF smoke did run.
- Whether separate embedding-model retrieval ran: Not yet
- Exact next proof step: implement and test the Matter Search embedding install/retrieval path, then run hardware Q4 inference proof.

## 2026-04-23 iPhone and Android model-path update

- Branch: `alpha-lawyer-usable-app`
- iPhone model source: iOS on-device private assistant when available
- iPhone model download status then: no separate OGemma 4 or Hugging Face model was downloaded in that pass
- Android model source: backend-served compatible MediaPipe `.task` artifact when explicitly configured outside the repo
- Whether model files were committed: No
- Whether iPhone setup was manually tapped on Aman's device in this update: Not yet
- Whether Android real `mediapipe_llm` inference ran on a physical Android device: Not yet
- What was validated instead:
  - iOS Swift tests passed for `system_model` runtime health without a downloaded path
  - Android unit tests passed for preserving `.task` filenames during backend artifact install
  - Android Ask Ross now routes matter Q&A through the installed local runtime when available, with deterministic local fallback
  - Android dock command tests still pass for task creation, date saving, and export generation
- Remaining blocker:
  - a real Android `.task` artifact and physical Android device are still required before claiming Android real-model execution
  - Aman's iPhone still needs a manual setup check before claiming the iOS on-device assistant is available on that exact phone

## 2026-04-19 Android physical-device proof attempt

- Date: 2026-04-19
- Branch: `alpha-android-real-proof`
- Commit observed during validation: `e10c7f4`
- Platform: Android physical-device proof attempt with repo-wide validation
- Device model: Not available. No physical Android device was connected.
- Android version: Not available. No physical Android device was connected.
- Runtime mode: Not run. Requested proof target remains `mediapipe_llm`.
- Model artifact kind: developer-provided local `.task` artifact
- Model artifact source: Not provided in this session
- Model checksum status: Not configured in this session
- Whether model file was committed: No
- Whether inference actually ran: No
- Whether deterministic fallback was used: Not applicable for a physical-device proof run because no Android extraction was executed on-device
- Runtime health result: Not observed on a physical Android device
- Fixture used: none for a real-device Android run
- Extraction mode: `Case Associate`
- Duration: not recorded because no real-device inference ran
- Fields found: not recorded because no real-device inference ran
- Fields verified: not recorded because no real-device inference ran
- Fields needing review: not recorded because no real-device inference ran
- Unsupported accepted count: not recorded because no real-device inference ran
- Schema valid: not recorded because no real-device inference ran
- Source refs present: not recorded because no real-device inference ran
- Export generated: not recorded because no real-device inference ran
- Privacy ledger checked: not checked on a physical Android device in this session
- Logs checked for raw prompt/source: not checked on a physical Android device in this session
- Network checked for model calls: not checked on a physical Android device in this session
- Exact blocker:
  - no physical Android device connected
  - no developer-provided compatible `.task` model artifact configured or supplied
- What was validated instead:
  - `scripts/dev/android-real-inference-smoke.sh` cleanly skipped with `Skipping: no physical Android device is connected.`
  - `adb devices -l` returned no attached devices
  - no `ROSS_ENABLE_REAL_LOCAL_INFERENCE`, `ROSS_LOCAL_RUNTIME`, or `ROSS_LOCAL_MODEL_*` environment variables were configured in this session
  - Android baseline validation passed: `./gradlew :app:testDebugUnitTest :app:assembleDebug`
  - Rust, backend, privacy-guard, and iOS validation suites passed after a small iOS runtime-health safety fix
  - backend live smoke passed for:
    - `GET /model-catalog`
    - `POST /model-download/session`
    - `GET /dev-artifacts/:artifactId` with `Range`
    - `POST /public-law/search`
  - optional backend external-model metadata and serving smoke passed with a safe temporary file outside the repo, and the backend did not expose the local file path
- Failures/blockers:
  - Android real local inference was not run, so there is still no proof yet that `mediapipe_llm` executed on a physical device for Ross
- Next exact manual step:
  - connect one physical Android device
  - supply one compatible developer-provided `.task` model artifact outside the repo
  - set:
    - `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
    - `ROSS_LOCAL_RUNTIME=mediapipe_llm`
    - `ROSS_LOCAL_MODEL_PATH=<app-readable device path>`
    - `ROSS_LOCAL_MODEL_PUSH_SOURCE=<absolute source path outside the repo>` when using the smoke helper
    - optional `ROSS_LOCAL_MODEL_CHECKSUM=<sha256>`
  - rerun `/Users/amanpandey/projects/ross/scripts/dev/android-real-inference-smoke.sh`
  - install and launch the Android debug APK
  - confirm `Settings > Private AI > Technical details` shows real runtime available with fallback inactive
  - run `Run local inference smoke`
  - complete one synthetic `Case Associate` extraction, verify source-backed fields, confirm unsupported accepted count stays `0`, generate one export, inspect the Privacy Ledger, inspect `adb logcat`, and record the observed result here without pasting prompt text, source text, or model output
