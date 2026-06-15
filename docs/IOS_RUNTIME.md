# iOS Gemma 4 Runtime

## Current Status

Ross no longer uses the old `Gemma4DemoRuntime`-only path described in earlier notes. The iOS app now has four runtime lanes:

| Lane | Code path | Status |
| --- | --- | --- |
| Deterministic development runtime | `AlphaLocalModelRuntime` deterministic provider | Used by tests and local CI-style validation. It must not be claimed as real model execution. |
| GGUF llama.cpp runtime | `AlphaLlamaCppEngine` and `AlphaLlamaCppProvider` | Simulator smoke passed on June 2, 2026 with a local GGUF developer artifact. |
| Experimental MLX local-directory runtime | `AlphaMLXLocalProvider` with `mlx-swift-lm` | Added as an explicit opt-in iPhone/macOS path for developer-supplied local model directories. It can also use an optional developer-supplied draft model for speculative decoding. It is not yet wired into the normal download/install catalog and has not been proven on a physical iPhone. |
| Apple on-device assistant path | `apple_foundation_models` pack mode | Available only when the OS/device supports it and explicit runtime checks pass. |

## Verified Evidence

- Swift package tests cover registry parsing, artifact validation, download-state recovery, Ask routing, imported text/PDF/image behavior, and multilingual source-preserving fallback.
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

The new experimental MLX lane also remains unproven on physical iPhone hardware. It currently supports only developer-supplied local directories selected through explicit runtime overrides such as `ROSS_LOCAL_RUNTIME=mlx_swift_lm`. Optional speculative decoding can be enabled with `ROSS_LOCAL_DRAFT_MODEL_PATH` and `ROSS_LOCAL_DRAFT_MODEL_TOKENS` when both main and draft directories share a compatible tokenizer.

## Build Notes

For local Swift verification:

```bash
swift test --package-path ios
```

For app integration, build and launch through Xcode or XcodeBuildMCP using the shared `Ross` scheme. Simulator success is useful evidence for compilation and integration, but it does not replace physical-device proof for model downloads, storage pressure, or hardware runtime behavior.
