# Model Artifact Status

The current status of model artifacts for ROSS-Gemma4.

| Tier | Active Model ID | Upstream Identity | Desired Format | Status | Catalog URL configured | `releaseReady` |
| --- | --- | --- | --- | --- | --- | --- |
| Quick Start | `gemma-4-e4b-q4` | `unsloth/gemma-4-E4B-it-GGUF` | GGUF UD-Q4_K_XL | Configured direct Hugging Face URL for the latest plain GGUF release; historical physical iPhone standard GGUF full-matrix evidence exists from June 19, 2026, but the current checkout still needs a fresh guarded full-matrix rerun after the smoke-summary protocol change before making a new release proof claim; MTP draft activation is simulator-proven but failed physical full-matrix quality gates | `true` | `true` |
| Case Associate | `gemma-4-12b-q4` | `unsloth/gemma-4-12b-it-GGUF` | GGUF UD-Q4_K_XL | Configured direct Hugging Face URL for the latest plain GGUF release; blocked safely as `insufficient_device_memory` on the 7 GB iPhone class; representative-device proof still pending | `true` | `true` |
| Senior Drafting Support | `gemma-4-26b-a4b-q4` | `unsloth/gemma-4-26B-A4B-it-GGUF` | GGUF UD-Q4_K_XL | Configured direct Hugging Face URL for the latest plain GGUF release; physical-device download proof still pending | `true` | `true` |

The legacy Flash pack remains in the registry only for compatibility and recovery flows. It is no longer a product-visible assistant tier.

## Current Proof

- iOS Swift registry: `ios/Ross/AlphaFoundation/AlphaRossModel.swift`
- Shared canonical registry: `shared/constants/privateAssistantModelRegistry.json`
- Simulator real-runtime proof: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start` on 2026-06-02.
- Physical iPhone GGUF proof: Quick Start E4B and Gemma 2 2B baseline have historical guarded smoke evidence on 2026-06-19. See `benchmarks/physical-iphone-2026-06-19/README.md`. The current post-`5aa1f74a` smoke-summary protocol has not yet been rerun as a full physical matrix, so treat those logs as historical GGUF evidence, not proof that the current checkout has completed final morning validation.
- MTP draft activation is simulator-proven with `ROSS_RUNTIME_IDENTITY acceleration=draftModelSpeculative draft_status=active context_tokens=1024`, but it is not physical benchmark-proven yet. The June 19, 2026 iPhone 15 Pro MTP checkpoints failed safely: one strict validation run reported `draft_status=validator_failed`, `error=draft_validator_failed`, and `mmap failed: Cannot allocate memory`; a later full-matrix draft run reached draft acceleration on early stages but failed quality gates with `bengali_error=draft_output_degenerate`. June 20, 2026 simulator reruns against the 12B primary plus `/Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf` also activated draft acceleration with both `draft_tokens=2` and `draft_tokens=1`, then failed closed as `draft_output_degenerate` after control-token output `<|channel>11111111111`. A June 20, 2026 E4B simulator run against `/Users/amanpandey/model-artifacts/gemma-4-E4B-it-UD-Q4_K_XL.gguf` plus `/Users/amanpandey/model-artifacts/mtp-gemma-4-E4B-it.gguf` activated draft acceleration but accepted zero useful draft tokens in both low-token stages, so it failed closed as `draft_stage_invalid`. None of these are MTP benchmark evidence. MLX and CoreAI/CoreML are not benchmark-proven yet. All non-GGUF lanes require matching `ROSS_RUNTIME_IDENTITY` and successful generation, not fallback through GGUF. Morning MTP proof also requires paired installed inventory for the requested tier and same manifest `pack`: `installed_gguf status=present` plus `installed_mtp_draft status=present`; every benchmark summary stage must keep draft acceleration active, non-degenerate, and positive-acceptance.
- June 20, 2026 local inventory proves the E4B and 12B GGUF/MTP catalog files are present and checksum-matched under `/Users/amanpandey/model-artifacts`. It also proves the local E4B MLX primary directory is reachable as `lane=mlx status=present`, but that is routing/preflight evidence only: the catalog row still reports a size/checksum mismatch (`gemma-4-E4B-it-qat-4bit` actual bytes `6830820301`, checksum `7369f812605934a9c35201a909d3bf6d37082222b6ad605f363edfbb80b7aa21`) and remains non-release-ready until generation succeeds under `actual_runtime=mlx_swift_lm`. The E4B MLX assistant/draft directory is still not a usable draft lane: top-level inventory reports `lane=mlx_draft status=missing reason=unsupported_gemma4_multimodal`, and the catalog row also reports a size/checksum mismatch (`gemma-4-E4B-it-qat-assistant-6bit` actual bytes `97065396`, checksum `33515b28ce5cd9b177c05ededc41caca7b6987e336baa38ba4a99fc33c882efb`). CoreAI/CoreML adapter inventory remains `missing` except for the system-model sentinel, which still requires OS runtime availability plus generation smoke proof.
- Local smoke artifact: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Local smoke artifact SHA-256: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- New smoke logs include `bengali_native_model` and `hindi_native_model` so QA can distinguish native multilingual model output from Ross's source-preserving fallback.
- Matter Search registry consistency is checked by `scripts/verify-model-artifacts.sh`: every capability tier must reference registered retrieval model IDs, and the private assistant registry must include both EmbeddingGemma 300M and the Gemma 4 embedding fallback.

## Remaining Proof Steps

1. Run no-launch artifact preflights with `scripts/ios-simulator-local-model-smoke.sh --preflight-only` for any local GGUF, MLX, CoreAI/CoreML adapter, or `system://...` sentinel that will be referenced during validation.
2. Re-run the morning physical-device checkpoint with guarded short smokes for GGUF baseline, MTP low-token proof, MLX identity/generation if an artifact exists, and CoreAI/CoreML identity/generation if available.
3. Confirm pause/resume, checksum/provider digest handling, runtime validation, repair, and re-download.
4. Import real PDF/image/text files from Files/iCloud/Downloads and ask source-grounded English, Hindi, and Bengali questions.
5. Record device performance, storage, privacy-ledger, and fallback status in the QA report.
6. Implement and prove the separate Matter Search embedding download/install/retrieval lifecycle.
