# Model Artifact Status

The current status of model artifacts for ROSS-Gemma4.

| Tier | Active Model ID | Upstream Identity | Desired Format | Status | Catalog URL configured | `releaseReady` |
| --- | --- | --- | --- | --- | --- | --- |
| Quick Start | `gemma-4-e4b-q4` | `unsloth/gemma-4-E4B-it-GGUF` | GGUF UD-Q4_K_XL | Configured direct Hugging Face URL for the latest plain GGUF release; physical iPhone standard GGUF full-matrix smoke passed on June 19, 2026; MTP draft activation is simulator-proven but failed physical full-matrix quality gates | `true` | `true` |
| Case Associate | `gemma-4-12b-q4` | `unsloth/gemma-4-12b-it-GGUF` | GGUF UD-Q4_K_XL | Configured direct Hugging Face URL for the latest plain GGUF release; blocked safely as `insufficient_device_memory` on the 7 GB iPhone class; representative-device proof still pending | `true` | `true` |
| Senior Drafting Support | `gemma-4-26b-a4b-q4` | `unsloth/gemma-4-26B-A4B-it-GGUF` | GGUF UD-Q4_K_XL | Configured direct Hugging Face URL for the latest plain GGUF release; physical-device download proof still pending | `true` | `true` |

The legacy Flash pack remains in the registry only for compatibility and recovery flows. It is no longer a product-visible assistant tier.

## Current Proof

- iOS Swift registry: `ios/Ross/AlphaFoundation/AlphaRossModel.swift`
- Shared canonical registry: `shared/constants/privateAssistantModelRegistry.json`
- Simulator real-runtime proof: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start` on 2026-06-02.
- Physical iPhone GGUF proof: Quick Start E4B and Gemma 2 2B baseline passed guarded smokes on 2026-06-19. See `benchmarks/physical-iphone-2026-06-19/README.md`.
- MTP draft activation is simulator-proven with `ROSS_RUNTIME_IDENTITY acceleration=draftModelSpeculative draft_status=active context_tokens=2048`, but it is not physical benchmark-proven yet. The June 19, 2026 iPhone 15 Pro MTP checkpoints failed safely: one strict validation run reported `draft_status=validator_failed`, `error=draft_validator_failed`, and `mmap failed: Cannot allocate memory`; a later full-matrix draft run reached draft acceleration on early stages but failed quality gates with `bengali_error=draft_output_degenerate`. Neither is MTP benchmark evidence. MLX and CoreAI/CoreML are not benchmark-proven yet. All non-GGUF lanes require matching `ROSS_RUNTIME_IDENTITY` and successful generation, not fallback through GGUF. Morning MTP proof also requires paired installed inventory for the requested tier: `installed_gguf status=present` plus `installed_mtp_draft status=present`; every benchmark summary stage must keep draft acceleration active and non-degenerate.
- Local smoke artifact: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Local smoke artifact SHA-256: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- New smoke logs include `bengali_native_model` and `hindi_native_model` so QA can distinguish native multilingual model output from Ross's source-preserving fallback.
- Matter Search registry consistency is checked by `scripts/verify-model-artifacts.sh`: every capability tier must reference registered retrieval model IDs, and the private assistant registry must include both EmbeddingGemma 300M and the Gemma 4 embedding fallback.

## Remaining Proof Steps

1. Re-run the morning physical-device checkpoint with guarded short smokes for GGUF baseline, MTP low-token proof, MLX identity/generation if an artifact exists, and CoreAI/CoreML identity/generation if available.
2. Confirm pause/resume, checksum/provider digest handling, runtime validation, repair, and re-download.
3. Import real PDF/image/text files from Files/iCloud/Downloads and ask source-grounded English, Hindi, and Bengali questions.
4. Record device performance, storage, privacy-ledger, and fallback status in the QA report.
5. Implement and prove the separate Matter Search embedding download/install/retrieval lifecycle.
