# Model Artifact Status

The current status of model artifacts for ROSS-Gemma4.

| Tier | Active Model ID | Upstream Identity | Desired Format | Status | Catalog URL configured | `releaseReady` |
| --- | --- | --- | --- | --- | --- | --- |
| Quick Start | `gemma-4-e4b-q4` | `unsloth/gemma-4-E4B-it-qat-GGUF` | GGUF UD-Q4_K_XL | Configured direct Hugging Face URL; simulator GGUF smoke proved local runtime with a developer artifact; physical-device proof pending | `true` | `true` |
| Case Associate | `gemma-4-12b-q4` | `unsloth/gemma-4-12B-it-qat-GGUF` | GGUF UD-Q4_K_XL | Configured direct Hugging Face URL; physical-device download proof still pending | `true` | `true` |
| Senior Drafting Support | `gemma-4-26b-a4b-q4` | `unsloth/gemma-4-26B-A4B-it-qat-GGUF` | GGUF UD-Q4_K_XL | Configured direct Hugging Face URL; physical-device download proof still pending | `true` | `true` |

The legacy Flash pack remains in the registry only for compatibility and recovery flows. It is no longer a product-visible assistant tier.

## Current Proof

- iOS Swift registry: `ios/Ross/AlphaFoundation/AlphaRossModel.swift`
- Shared canonical registry: `shared/constants/privateAssistantModelRegistry.json`
- Simulator real-runtime proof: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start` on 2026-06-02.
- Local smoke artifact: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Local smoke artifact SHA-256: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- New smoke logs include `bengali_native_model` and `hindi_native_model` so QA can distinguish native multilingual model output from Ross's source-preserving fallback.
- Matter Search registry consistency is checked by `scripts/verify-model-artifacts.sh`: every capability tier must reference registered retrieval model IDs, and the private assistant registry must include both EmbeddingGemma 300M and the Gemma 4 embedding fallback.

## Remaining Proof Steps

1. Run physical iPhone setup download for a full configured GGUF.
2. Confirm pause/resume, checksum/provider digest handling, runtime validation, repair, and re-download.
3. Import real PDF/image/text files from Files/iCloud/Downloads and ask source-grounded English, Hindi, and Bengali questions.
4. Record device performance, storage, privacy-ledger, and fallback status in the QA report.
5. Implement and prove the separate Matter Search embedding download/install/retrieval lifecycle.
