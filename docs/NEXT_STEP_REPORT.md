# Ross Gemma 4 Model Strategy Update

## Branch Used

- `gemma-4-gguf-model-strategy`

## What Changed

- added canonical Gemma 4-first model registry metadata
- mapped Quick Start, Case Associate, and Senior Drafting Support to Gemma 4 Q4 tiers
- added separate Matter Search retrieval model metadata
- added backend `ROSS_MODEL_CATALOG_MODE=dev | production_metadata`
- kept deterministic tiny artifacts as the default backend catalog mode
- updated Android and iOS user-facing tier sizes and copy
- moved technical model details out of normal Private Assistant UI
- documented the Gemma 4 strategy and hardware estimates

## Model Mapping

- Quick Start -> Gemma 4 E2B Q4, about 430 MB
- Case Associate -> Gemma 4 E4B Q4, about 1.1-1.3 GB
- Senior Drafting Support -> Gemma 4 26B-A4B Q4, about 2.5 GB
- Matter Search -> EmbeddingGemma 300M preferred, Gemma 4-Embedding 0.6B Q4 fallback

## Current Truth

- The registry and catalog metadata are updated.
- The backend still serves tiny deterministic artifacts by default.
- Production metadata mode does not serve real model files.
- No model files are committed or bundled.
- Normal UI should hide model names and runtime details.

## Still Unimplemented

- production serving for real Q4 files
- Android native Q4 inference
- iOS Q4 inference proof with a linked runtime bridge
- separate embedding model download/install lifecycle
- hardware proof for each tier

## Exact Next Recommended Step

Implement the Matter Search embedding model lifecycle first: catalog entry, download state, install state, retrieval-provider health, and a small local RAG smoke test that proves source retrieval remains on-device.
