# iOS Gemma 4 Runtime

## Current Status

Ross no longer uses the old `Gemma4DemoRuntime`-only path described in earlier notes. The iOS app now has four runtime lanes:

| Lane | Code path | Status |
| --- | --- | --- |
| Deterministic development runtime | `AlphaLocalModelRuntime` deterministic provider | Used by tests and local CI-style validation. It must not be claimed as real model execution. |
| GGUF llama.cpp runtime | `AlphaLlamaCppEngine` and `AlphaLlamaCppProvider` | Simulator smoke passed on June 2, 2026 with a local GGUF developer artifact. The project is now pinned to `llama.swift` `2.9672.0` as of June 17, 2026, which resolves the newer upstream `llama.cpp` Apple XCFramework build `b9672`, and the GGUF lane continues to expose speculative draft acceleration for Gemma 4 MTP companions while the visible 3-pack ladder points at the newer Unsloth QAT GGUF repos. |
| MLX local-directory runtime | `AlphaMLXLocalProvider` with `mlx-swift-lm` | Supported as an iPhone/macOS path for MLX model directories. The installer can unpack ZIP-packaged MLX directories, and the E4B / 12B MLX tiers now accept official Gemma 4 assistant draft companions for speculative decoding. Physical iPhone validation is still pending. |
| Apple on-device assistant path | `apple_foundation_models` pack mode | Available only when the OS/device supports it and explicit runtime checks pass. |

## Verified Evidence

- Swift package tests cover registry parsing, artifact validation, download-state recovery, Ask routing, imported text/PDF/image behavior, and multilingual source-preserving fallback.
- Local model smoke runs now emit `ROSS_RUNTIME_IDENTITY` before generation. Treat this as the authority for provider name, requested runtime, actual runtime, artifact kind/path type, acceleration mode, draft metadata including draft artifact path type, context size, GPU/offload summary, fallback state, and availability.
- Explicit debug/smoke runtime overrides do not borrow artifact paths from an installed pack with a different runtime. MLX, GGUF, and CoreAI/CoreML lanes must use an explicit debug artifact path, a matching installed pack, or a system-model sentinel where that runtime supports one.
- If an active runtime fails health before generation, smoke now emits the same identity marker with `available=false`, the actual provider object selected for that failed path, and the concrete error category. This is expected for missing or malformed MLX/CoreAI artifacts and is still routing evidence, not a generation benchmark.
- Smoke pass/fail lines include stage-prefixed benchmark fields such as `source_input_tokens`, `source_output_tokens`, `source_token_speed`, `source_first_token_ms`, and `source_measured_tokens`. Prefer measured token fields when `*_measured_tokens=true`; otherwise treat counts/speeds as runtime estimates.
- Each app smoke run emits `ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX` before generation. `full` covers source-bound English legal QA, source-bound Bengali/Hindi/Tamil/Telugu legal QA, and a no-document open query; `quick` covers English source-bound QA plus the open query; `mtp_quick` uses the same short matrix with 64-token caps for safer draft-acceleration validation.
- After identity guardrails pass, smoke helpers print `ROSS_SMOKE_BENCHMARK_SUMMARY` with the verified runtime identity, acceleration metadata, smoke profile, benchmark matrix profile/cases/stages, elapsed time, and any stage token metrics from the pass line. Use that summary for benchmark tables instead of scraping unguarded app logs. A pass marker without `ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX` is rejected as `missing_benchmark_matrix`.
- In the product UI, answer-level `Tokens processed` and `Token speed` stay out of the main response chrome and are available from the hidden Answer Details surface through the info/context-menu action. This keeps performance metadata inspectable without adding cognitive load to every answer.
- Failed simulator, seeded-GGUF, and installed-pack smokes print `ROSS_SMOKE_FAILURE_SUMMARY` with the same runtime identity shape plus failure fields such as stage errors, grounding flags, draft status, and any emitted token metrics. Use these lines for triage only; they do not turn a failed MLX/CoreAI/MTP run into a benchmark.
- `scripts/ios-simulator-local-model-smoke.sh` provides the same pass-only identity guardrail for simulator checks. It is useful for overnight-safe GGUF/MLX/CoreAI routing checks because it uses `simctl` and never seeds or launches a physical iPhone.
- The cabled-device smoke helpers fail a run if a pass marker arrives without `ROSS_RUNTIME_IDENTITY`, or if the requested runtime does not match the actual runtime reported by the app. MLX/CoreAI/MTP numbers must not be recorded from a GGUF identity marker.
- Passing simulator and cabled-device smoke helpers also reject impossible runtime artifact identity, such as an MLX pass with a file-backed GGUF artifact or a CoreAI adapter pass that reports the system sentinel path type.
- Assistant-download smokes also fail closed for explicit runtime requests: the selected terminal job and installed pack must match the requested runtime, and the shell helper rejects unknown runtime labels or pass markers whose runtime field differs from the requested lane. This prevents an MLX/CoreAI download smoke from passing from a previously installed GGUF pack.
- Failed smoke runs remain failed, but the helpers now also validate any identity marker emitted before failure. This catches mislabeled failed MLX/CoreAI/MTP attempts during triage instead of leaving the mismatch hidden inside noisy logs.
- `scripts/ios-device-installed-pack-smoke.sh` also preflights the selected manifest before launching the app: MLX requires `artifactKind=mlx_directory`, GGUF requires a GGUF/local-model artifact kind, and Apple Foundation/CoreAI requires a system/foundation/CoreAI/CoreML adapter kind. This prevents an impossible manifest/runtime pair from consuming a device benchmark slot.
- MTP proof requires `--require-draft-acceleration` plus an identity marker with `acceleration=draftModelSpeculative`, `draft_status=active`, non-`nil` `draft_tokens`, and non-`nil` `draft_model`. The installed-pack helper also fails before launch if the selected manifest lacks `draftArtifact.relativePath`, uses an incompatible draft artifact kind, or requests draft proof for the Apple Foundation/CoreAI lane. The `mtp_quick` smoke profile exists for a short, low-output validation pass; it is not a long stress benchmark.
- GGUF identity markers now include `draft_status` so standard-generation MTP attempts are diagnosable instead of ambiguous. Expected values include `active`, `no_draft_configured`, `draft_file_unavailable`, `draft_token_policy_blocked`, `validator_rejected`, `validator_failed`, and `runtime_unavailable`.
- If the main GGUF runtime is available but draft validation fails, the identity marker stays `available=true` for the baseline runtime and reports a draft-specific `error` such as `draft_validator_rejected`, `draft_validator_failed`, `draft_token_policy_blocked`, or `draft_file_unavailable`. Treat those as failed MTP proof, not failed GGUF proof.
- Simulator MTP proof also requires `--draft-model`; the helper now fails before launch if `--require-draft-acceleration` is requested without a draft artifact path, if GGUF/MTP proof receives a non-GGUF draft artifact, if MLX draft proof receives a file-like GGUF/bin artifact or malformed MLX directory, or if CoreAI/CoreML asks for draft proof. As of June 19, 2026, the local repo scan only found the main simulator GGUF and the 12B GGUF artifact, not a usable draft GGUF, so no new simulator MTP acceleration number is claimed from this checkpoint.
- `docs/REAL_MODEL_QA_RESULTS.md` records the June 2, 2026 simulator GGUF smoke:
  - runtime: `gemma_local_runtime`
  - tier: `quick_start`
  - artifact: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
  - SHA-256: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- The smoke harness now reports native-model markers such as `bengali_native_model` and `hindi_native_model` so QA can distinguish direct multilingual model output from Ross's source-preserving fallback.

## Still Not Proven

Do not claim release-ready physical iPhone inference until these are recorded:

1. A configured multi-GB GGUF is downloaded through the app on a physical iPhone.
2. Resume/restart, provider size or checksum handling, validation, activation, repair, and deletion are observed on-device.
3. Imported PDF, image, and text files from Files/iCloud/Downloads are used in Ask Ross with source-grounded English, Hindi, and Bengali questions.
4. Device performance, storage use, privacy ledger entries, logs, and fallback behavior are recorded in `docs/REAL_MODEL_QA_RESULTS.md`.

The MLX lane remains unproven on physical iPhone hardware. It now supports both developer-supplied local directories and ZIP-packaged MLX installs, but physical-device validation is still pending.

Before morning device validation, run `scripts/ios-morning-runtime-checkpoint-plan.sh --device <udid>` to print the short, guarded command sequence without launching the app. The printed order starts with `--list-only`, then GGUF baseline, MTP `mtp_quick` with `--require-draft-acceleration`, MLX quick, and CoreAI/CoreML quick if those installed artifacts are available. The MTP plan intentionally does not pass `--allow-device-proof-pack`, so a seeded GGUF baseline cannot masquerade as installed MTP proof.

Any MLX benchmark must show `actual_runtime=mlx_swift_lm` in `ROSS_RUNTIME_IDENTITY`. Any Apple built-in/CoreAI/CoreML benchmark must show `actual_runtime=apple_foundation_models`. In this codebase, `coreai` and `coreml` are smoke/runtime aliases for Apple's Foundation Models path, not separate benchmark lanes. If either lane reports `actual_runtime=gemma_local_runtime`, the run is a GGUF fallback or routing error, not a valid MLX/CoreAI/CoreML benchmark.

The Apple built-in/CoreAI/CoreML debug-smoke path now treats `artifactKind=system_model` and `modelPath=system-model` or `system://...` as the system Foundation Models runtime, not as a missing adapter file. A June 19, 2026 simulator check produced a real identity marker with `provider=AlphaFoundationModelsLocalProvider`, `actual_runtime=apple_foundation_models`, and `artifact_path_type=system`; generation still failed in simulator, now categorized as `coreai_generation_failed`, so this is routing evidence only, not a CoreAI/CoreML generation benchmark. If the provider cannot become available before generation, the failed identity marker reports `provider=AlphaUnavailableRealLocalModelProvider` while keeping `actual_runtime=apple_foundation_models`.

CoreAI/Foundation identity markers report `acceleration=standard`, `draft_tokens=nil`, `draft_model=nil`, and `draft_status=not_supported`. That lane is system-managed; do not treat the absence of draft acceleration as an MTP-style failure, and do not count it as a benchmark unless generation succeeds under `actual_runtime=apple_foundation_models`.

Clear unavailable categories for benchmark triage:

- `missing_mlx_artifact`: the requested MLX lane did not receive a usable MLX directory path, including the case where a GGUF file was supplied to `--runtime mlx`.
- `invalid_mlx_artifact`: the requested MLX directory exists but lacks the required MLX runtime files.
- `invalid_mlx_draft_artifact`: the primary MLX directory is usable, but the configured draft companion is not.
- MLX identity markers also carry `draft_status`; MLX draft acceleration is reported as `active` only when the primary runtime is available and the draft directory is usable. Invalid or unsupported draft companions stay `acceleration=standard` with a concrete `draft_status` instead of poisoning the whole MLX lane.
- When the primary MLX runtime is available but the draft companion is missing, invalid, or unsupported, `ROSS_RUNTIME_IDENTITY` keeps `available=true` for MLX and reports the draft-specific `error` category. Treat that as failed MLX draft proof, not failed MLX standard-generation proof.
- `missing_coreai_artifact`: a configured CoreAI/Foundation adapter path was required but could not be opened.
- `unsupported_runtime_on_platform`: the Apple built-in/CoreAI runtime is unavailable on the current OS, device, or build.
- `coreai_generation_failed`: the Apple built-in/CoreAI provider was selected and available, but a generation call failed before returning a usable answer.

Ross now fails closed on malformed or known-bad Gemma 4 MLX archives instead of waiting for an inference-time crash:
- MLX install verification requires a directory with `config.json`, tokenizer metadata, and safetensors weights or an index before writing an installed-pack manifest.
- `gemma4_assistant` archives are still rejected as primary MLX targets, but they are now accepted as draft companions for speculative decoding on supported tiers.
- Gemma 4 26B-A4B MLX archives are rejected because the current upstream loader still does not support the MoE routing keys.
- Known Gemma 4 31B dense MLX archives are also treated as unsupported because the current stack can still crash on first generation.

If `ROSS_LOCAL_DRAFT_MODEL_PATH` points at an unsupported draft archive, Ross now drops back to standard MLX generation instead of poisoning the whole runtime.

CoreAI/CoreML adapter artifacts are file-backed Foundation Models adapters, not the same thing as the built-in `system_model` sentinel. Persistence keeps zero-byte `system://` shortcut behavior limited to true system packs; CoreML/Foundation adapter packs must keep their installed artifact identity and fail as `missing_coreai_artifact` if the adapter cannot be opened.

## Build Notes

For local Swift verification:

```bash
swift test --package-path ios
```

For app integration, build and launch through Xcode or XcodeBuildMCP using the shared `Ross` scheme. Simulator success is useful evidence for compilation and integration, but it does not replace physical-device proof for model downloads, storage pressure, or hardware runtime behavior.
