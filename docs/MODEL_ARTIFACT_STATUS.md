# Model Artifact Status

The current status of model artifacts for ROSS-Gemma4.

| Tier | Active Model ID | Upstream Identity | Desired Format | Status | `verified` | `releaseReady` |
| --- | --- | --- | --- | --- | --- | --- |
| Quick Associate | `gemma-4-e2b-q4` | `google/gemma-4-E2B-it` | GGUF Q4_K_M | Missing / Placeholders | `false` | `false` |
| Case Associate | `gemma-4-e4b-q4` | `google/gemma-4-E4B-it` | GGUF Q4_K_M | Missing / Placeholders | `false` | `false` |
| Senior Drafting Support | `gemma-4-26b-a4b-q4` | `google/gemma-4-26B-A4B-it` | GGUF Q4_K_M | Missing / Placeholders | `false` | `false` |

## Resolution Steps
1. Obtain the real GGUF files.
2. Run `./scripts/model-artifact-checksum.sh <file>` to obtain the metrics.
3. Replace the placeholder URLs and checksums in `AlphaRossModel.swift` and `privateAssistantModelRegistry.json`.
4. Update `verified: true` and `releaseReady: true`.
