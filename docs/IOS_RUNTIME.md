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
- Local model smoke runs now emit `ROSS_RUNTIME_IDENTITY` before generation. Treat this as the authority for provider name, requested runtime, actual runtime, artifact kind/path type, acceleration mode, draft metadata, context size, GPU/offload summary, fallback state, and availability.
- Smoke pass/fail lines include stage-prefixed benchmark fields such as `source_input_tokens`, `source_output_tokens`, `source_token_speed`, `source_first_token_ms`, and `source_measured_tokens`. Prefer measured token fields when `*_measured_tokens=true`; otherwise treat counts/speeds as runtime estimates.
- The cabled-device smoke helpers fail a run if a pass marker arrives without `ROSS_RUNTIME_IDENTITY`, or if the requested runtime does not match the actual runtime reported by the app. MLX/CoreAI/MTP numbers must not be recorded from a GGUF identity marker.
- `scripts/ios-device-installed-pack-smoke.sh` also preflights the selected manifest before launching the app: MLX requires `artifactKind=mlx_directory`, GGUF requires a GGUF/local-model artifact kind, and Apple Foundation/CoreAI requires a system/foundation/CoreAI/CoreML adapter kind. This prevents an impossible manifest/runtime pair from consuming a device benchmark slot.
- MTP proof requires `--require-draft-acceleration` plus an identity marker with `acceleration=draftModelSpeculative`, non-`nil` `draft_tokens`, and non-`nil` `draft_model`. The `mtp_quick` smoke profile exists for a short, low-output validation pass; it is not a long stress benchmark.
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

Any MLX benchmark must show `actual_runtime=mlx_swift_lm` in `ROSS_RUNTIME_IDENTITY`. Any Apple built-in/CoreAI/CoreML benchmark must show `actual_runtime=apple_foundation_models`. In this codebase, `coreai` and `coreml` are smoke/runtime aliases for Apple's Foundation Models path, not separate benchmark lanes. If either lane reports `actual_runtime=gemma_local_runtime`, the run is a GGUF fallback or routing error, not a valid MLX/CoreAI/CoreML benchmark.

Clear unavailable categories for benchmark triage:

- `missing_mlx_artifact`: the requested MLX lane did not receive a usable MLX directory path, including the case where a GGUF file was supplied to `--runtime mlx`.
- `invalid_mlx_artifact`: the requested MLX directory exists but lacks the required MLX runtime files.
- `invalid_mlx_draft_artifact`: the primary MLX directory is usable, but the configured draft companion is not.
- `missing_coreai_artifact`: a configured CoreAI/Foundation adapter path was required but could not be opened.
- `unsupported_runtime_on_platform`: the Apple built-in/CoreAI runtime is unavailable on the current OS, device, or build.

Ross now fails closed on known-bad Gemma 4 MLX archives instead of waiting for an inference-time crash:
- `gemma4_assistant` archives are still rejected as primary MLX targets, but they are now accepted as draft companions for speculative decoding on supported tiers.
- Gemma 4 26B-A4B MLX archives are rejected because the current upstream loader still does not support the MoE routing keys.
- Known Gemma 4 31B dense MLX archives are also treated as unsupported because the current stack can still crash on first generation.

If `ROSS_LOCAL_DRAFT_MODEL_PATH` points at an unsupported draft archive, Ross now drops back to standard MLX generation instead of poisoning the whole runtime.

## Build Notes

For local Swift verification:

```bash
swift test --package-path ios
```

For app integration, build and launch through Xcode or XcodeBuildMCP using the shared `Ross` scheme. Simulator success is useful evidence for compilation and integration, but it does not replace physical-device proof for model downloads, storage pressure, or hardware runtime behavior.
