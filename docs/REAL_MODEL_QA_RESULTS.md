# Real Model QA Results

## 2026-06-19 iOS simulator GGUF benchmark checkpoint

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`, `E36AB177-2287-4112-8225-339048142D11`)
- Runtime mode: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Whether model files were committed: No
- Whether the simulator app was rebuilt before smoke: Yes
- Runtime identity marker:
  - `ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured context_tokens=14336 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true error=nil`
- Quick profile result: passed.
- Quick profile pass marker:
  - `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime tier=quick_start profile=quick elapsed=66.81s source_raw_chars=467 source_parsed_chars=202 general_output_chars=442 source_refs=1 source_native_model=true general_native_model=true source_input_tokens=207 source_output_tokens=118 source_token_speed=8.93 source_first_token_ms=14483 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil general_input_tokens=190 general_output_tokens=192 general_token_speed=7.86 general_first_token_ms=14796 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil`
- Quick benchmark summary:
  - `ROSS_SMOKE_BENCHMARK_SUMMARY provider=AlphaLlamaCppProvider runtime=gemma_local_runtime requested_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured context_tokens=14336 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true identity_error=nil profile=quick matrix_profile=quick matrix_cases=english_source_bound_document_qa,english_open_no_document_query matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192 elapsed=66.81s source_input_tokens=207 source_output_tokens=118 source_token_speed=8.93 source_first_token_ms=14483 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil general_input_tokens=190 general_output_tokens=192 general_token_speed=7.86 general_first_token_ms=14796 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil`
- Full variety profile result: passed after tightening Tamil/Telugu source anchors and capping those stages at 96 output tokens.
- Full variety pass marker:
  - `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime tier=quick_start profile=full elapsed=55.73s source_raw_chars=467 source_parsed_chars=202 bengali_output_chars=135 hindi_output_chars=270 tamil_output_chars=345 telugu_output_chars=102 general_output_chars=442 source_refs=1 bengali_source_refs=1 hindi_source_refs=1 tamil_source_refs=1 telugu_source_refs=1 source_native_model=true bengali_native_model=true hindi_native_model=true tamil_native_model=true telugu_native_model=true general_native_model=true source_input_tokens=207 source_output_tokens=118 source_token_speed=10.69 source_first_token_ms=13122 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil bengali_input_tokens=328 bengali_output_tokens=121 bengali_token_speed=7.95 bengali_first_token_ms=22669 bengali_measured_tokens=false bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil hindi_input_tokens=278 hindi_output_tokens=134 hindi_token_speed=9.37 hindi_first_token_ms=20394 hindi_measured_tokens=false hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil tamil_input_tokens=382 tamil_output_tokens=96 tamil_token_speed=8.36 tamil_first_token_ms=27727 tamil_measured_tokens=false tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil telugu_input_tokens=433 telugu_output_tokens=96 telugu_token_speed=9.13 telugu_first_token_ms=32645 telugu_measured_tokens=false telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil general_input_tokens=190 general_output_tokens=192 general_token_speed=10.30 general_first_token_ms=12831 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil`
- Full variety benchmark summary:
  - `ROSS_SMOKE_BENCHMARK_SUMMARY provider=AlphaLlamaCppProvider runtime=gemma_local_runtime requested_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured context_tokens=14336 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true identity_error=nil profile=full matrix_profile=full matrix_cases=english_source_bound_document_qa,bengali_source_bound_document_qa,hindi_source_bound_document_qa,tamil_source_bound_document_qa,telugu_source_bound_document_qa,english_open_no_document_query matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192,bengali:document_qa:bn:source_refs_required:max_tokens=192,hindi:document_qa:hi:source_refs_required:max_tokens=192,tamil:document_qa:ta:source_refs_required:max_tokens=96,telugu:document_qa:te:source_refs_required:max_tokens=96,general:open_query:en:no_source_refs:max_tokens=192 elapsed=55.73s source_input_tokens=207 source_output_tokens=118 source_token_speed=10.69 source_first_token_ms=13122 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil general_input_tokens=190 general_output_tokens=192 general_token_speed=10.30 general_first_token_ms=12831 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil bengali_input_tokens=328 bengali_output_tokens=121 bengali_token_speed=7.95 bengali_first_token_ms=22669 bengali_measured_tokens=false bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil hindi_input_tokens=278 hindi_output_tokens=134 hindi_token_speed=9.37 hindi_first_token_ms=20394 hindi_measured_tokens=false hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil tamil_input_tokens=382 tamil_output_tokens=96 tamil_token_speed=8.36 tamil_first_token_ms=27727 tamil_measured_tokens=false tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil telugu_input_tokens=433 telugu_output_tokens=96 telugu_token_speed=9.13 telugu_first_token_ms=32645 telugu_measured_tokens=false telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil`
- Observed behavior:
  - the fresh simulator build launches successfully
  - GGUF runtime identity is explicit and confirms no fallback
  - quick document-grounded handling and a general query both pass with native-model outputs
  - the fuller run exercises source, general, Bengali, Hindi, Tamil, and Telugu stages
  - every full-profile stage completed without provider errors and reported native-model output
  - Tamil and Telugu now retain source refs, satisfy grounding checks, and report bounded 96-token speed metrics
- Current interpretation:
  - simulator GGUF execution, hidden benchmark fields, token counts, token speed, first-token latency, and source-reference retention are working for this local 2B GGUF baseline
  - the full simulator GGUF variety bundle is green for source, Bengali, Hindi, Tamil, Telugu, and general query handling
  - this run does not prove MLX, CoreAI/CoreML, MTP, or physical-device performance

## 2026-06-18 physical iPhone intended 12B GGUF attempt

- Branch: `main`
- Platform: physical iPhone (`Aman's iPhone`, `iPhone16,1`, iOS `27.0`)
- Runtime mode: `gemma_local_runtime`
- Intended visible tier under test: `Case Associate`
- Model artifact used: `/Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf`
- Model bytes observed locally: `7366421920`
- Model SHA-256 observed locally: `ee33ab5be8e07aca1c269fc645eaed5f3298e089d52db29415839d8f29957020`
- Repo metadata SHA-256 recorded before follow-up reconciliation: `2f76adb77c0cbce35bf0f14c8a9d57f5a8c08528acf2edf3684b1eb38b075637`
- Live HEAD nuance observed on June 18, 2026:
  - the Hugging Face resolver still advertised `content-length: 7366421920`
  - `x-linked-etag` matched the local file hash `ee33ab5be8e07aca1c269fc645eaed5f3298e089d52db29415839d8f29957020`
  - the final CDN `etag` still showed `2f76adb77c0cbce35bf0f14c8a9d57f5a8c08528acf2edf3684b1eb38b075637`
- Follow-up reconciliation completed on June 18, 2026:
  - Ross production metadata was updated to pin the downloaded GGUF bytes hash `ee33ab5be8e07aca1c269fc645eaed5f3298e089d52db29415839d8f29957020`
  - the prior `2f76adb77c0cbce35bf0f14c8a9d57f5a8c08528acf2edf3684b1eb38b075637` value is now treated as the CDN/Xet reconstruction hash observed in `etag`, not as the downloaded file checksum contract
- Smoke helper: `/Users/amanpandey/projects/ross-gemma4/scripts/ios-device-gguf-smoke.sh`
- Smoke command:
  - `scripts/ios-device-gguf-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --model /Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf --tier caseAssociate --stage-timeout 120`
- Whether model files were committed: No
- Whether the intended 12B GGUF reached the physical device: Yes
- Whether generation passed on the physical device: No
- Observed device/runtime details:
  - the app resolved and opened the intended `Gemma-4-12B-It` GGUF from the physical app container on device
  - the smoke run reported `System physical memory: 7 GB`
  - Metal reported `recommendedMaxWorkingSetSize  =  5726.63 MB`
  - the active GPU path was `Apple A17 Pro GPU`
- Failure signature:
  - `llama_model_load: error loading model: mmap failed: Cannot allocate memory`
  - `ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=gemma_local_runtime tier=quick_start elapsed=98.53s source_error=inference_failed bengali_error=inference_failed hindi_error=inference_failed tamil_error=inference_failed telugu_error=inference_failed general_error=inference_failed ... source_native_model=true ... general_native_model=true`
- Observed physical-device behavior:
  - the helper successfully seeded the full 12B artifact plus manifest into `Library/Application Support/RossAlpha/model-packs/caseAssociate/`
  - Ross resolved the seeded debug pack, constructed the GGUF provider path, and repeatedly attempted real model loading for each smoke stage
  - every stage failed before generation because the model could not be memory-mapped on this 7 GB-class iPhone
  - the fail marker still reported `tier=quick_start` even though the seeded artifact lived under the `caseAssociate` slot, so the smoke tier label should not be treated as the authored pack slot in this run
- What this proves:
  - the intended Case Associate 12B artifact is reachable from the current cabled-device helper and the app can begin real on-device load on Aman's iPhone
  - the current `gemma-4-12b-it-UD-Q4_K_XL.gguf` footprint does not fit this physical iPhone's available memory budget
- What is still not proven:
  - successful physical-device generation for the intended 12B artifact on a 12 GB+ iPhone class target
  - physical iPhone download/resume/verify/activate of the production 12B artifact on a device that can run it
  - the longer-bundle comparison loop across GGUF, MLX, and CoreAI on a device that can actually run the intended 12B pack

## 2026-06-18 physical iPhone GGUF smoke via cabled-device helper

- Branch: `main`
- Platform: physical iPhone (`Aman's iPhone`, `iPhone16,1`, iOS `27.0`)
- Runtime mode: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Model SHA-256 observed locally: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- Smoke helper: `/Users/amanpandey/projects/ross-gemma4/scripts/ios-device-gguf-smoke.sh`
- Smoke command:
  - `scripts/ios-device-gguf-smoke.sh --device 00008130-000C74820130001C --model /Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf --tier quickStart --stage-timeout 45`
- Whether model files were committed: No
- Whether real GGUF inference ran on the physical device: Yes
- Latest proof marker:
  - `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start elapsed=88.34s source_raw_chars=337 source_parsed_chars=321 bengali_output_chars=275 hindi_output_chars=157 tamil_output_chars=400 telugu_output_chars=185 general_output_chars=558 source_refs=1 bengali_source_refs=1 hindi_source_refs=1 tamil_source_refs=1 telugu_source_refs=1 source_native_model=true bengali_native_model=true hindi_native_model=true tamil_native_model=true telugu_native_model=true general_native_model=true`
- Observed physical-device behavior:
  - the helper seeded the GGUF artifact into the app container and resolved the absolute on-device model path automatically
  - the app created a real llama.cpp context on the A17 Pro GPU and completed every smoke stage on device
  - English source grounding, Bengali Bangla-script output, Hindi Devanagari output, Tamil output, Telugu output, and the general cautious answer all passed in the same run
- What is still not proven:
  - the intended `Case Associate` 12B GGUF artifact on this physical iPhone
  - physical iPhone download/resume/verify/activate of the current multi-GB production GGUF artifacts
  - the longer-bundle comparison loop across GGUF, MLX, and CoreAI on this device

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
- Latest proof marker after Bengali prompt tightening: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start elapsed=89.36s source_raw_chars=339 source_parsed_chars=167 bengali_output_chars=151 hindi_output_chars=143 general_output_chars=283 source_native_model=true bengali_native_model=true hindi_native_model=true general_native_model=true`
- Earlier stricter marker before prompt tightening: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start elapsed=91.00s ... source_native_model=true bengali_native_model=false hindi_native_model=true general_native_model=true`
- Observed behavior:
  - the smoke runner used the explicit environment-provided debug pack directly instead of loading persisted app state first
  - the simulator process loaded the GGUF metadata, constructed the llama.cpp context, and completed all four smoke stages
  - the app was manually terminated after the pass marker with `xcrun simctl terminate`
- Harness improvement made during this pass:
  - `--local-model-smoke` now emits flushed stage markers to stderr around debug-pack selection, provider resolution, and each provider call
  - each provider stage is guarded by a configurable timeout and returns a fail output if generation times out
  - direct environment-supplied GGUF smoke skips heavyweight persisted-state runtime-health loading before provider execution
  - Bengali and Hindi matter-answer prompts now include concrete native-script source-word anchors
- Current interpretation:
  - real GGUF simulator inference is proven for English source grounding, Bengali Bangla-script output, Hindi Devanagari output, and general cautious output
  - the latest run proves native Bengali and Hindi model output on simulator; no language-preserving fallback was used in that run
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
