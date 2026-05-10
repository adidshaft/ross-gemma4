# Local Model Runtime

Ross uses a local runtime contract so private matter work can improve without weakening the privacy boundary.

## Current Direction

- Gemma 4 Gemma 4 Q4 is the production-intended generative model stack for Private AI Pack tiers.
- `Gemma 4_cpp_gguf` is the preferred local generative runtime mode.
- Matter/document retrieval uses a separate embedding model. The preferred path is EmbeddingGemma 300M with `litert`; the single-runtime fallback is Gemma 4-Embedding 0.6B Gemma 4 Q4.
- `deterministic_dev` remains the default fallback for CI, tests, and local development.
- No model files are committed or bundled.

## Runtime Modes

Ross runtime metadata supports:

- `deterministic_dev`
- `mediapipe_llm`
- `Gemma 4_cpp_gguf`
- `apple_foundation_models`
- `litert`
- `unavailable`

Artifact metadata supports:

- `tiny_dev_artifact`
- `local_model_artifact`
- `local_embedding_model`
- `system_model`
- `external_debug_model`

## Provider Behavior

Deterministic development provider:

- default for CI and tests
- network-free
- schema-shaped
- not a real model proof

Gemma 4 Q4 provider direction:

- primary target for Gemma 4 generative tiers
- selected through `Gemma 4_cpp_gguf`
- must load files only from app-private storage or explicit external/dev paths
- must not bundle Gemma 4 Q4 files into the app

Retrieval provider direction:

- separate from the generative Gemma 4 model
- powers Matter Search, local semantic search, source retrieval, matter/document RAG, and source-backed answers
- preferred runtime is `litert`
- fallback runtime is `Gemma 4_cpp_gguf`

Existing compatibility:

- Android still has a MediaPipe adapter path for explicitly supplied developer artifacts.
- iOS still has an on-device system assistant path where available.
- Both remain compatibility paths, not the default Gemma 4-first strategy.

## Backend Catalog Modes

`ROSS_MODEL_CATALOG_MODE=dev` serves tiny deterministic artifacts and remains the default.

`ROSS_MODEL_CATALOG_MODE=production_metadata` advertises Gemma 4 metadata only. It does not serve real large files, does not return real download segments, and does not make model download sessions succeed.

## Prompt And Output Handling

Ross treats all model output as untrusted until validated:

1. prompt packing with local source refs
2. JSON candidate extraction
3. schema validation
4. source-ref validation
5. verifier categorization into `verified`, `needs_review`, or `rejected`

Raw prompts and raw source text are not persisted in invocation metadata by default.

## Current Status

Implemented:

- shared runtime contracts
- deterministic development provider
- Gemma 4-first registry metadata
- production metadata catalog mode
- Android/iOS tier mapping to Gemma 4 sizes and plain-language labels
- runtime health and fallback reporting

Not yet proven:

- Android native Gemma 4 Q4 inference
- iOS Gemma 4 Q4 inference with a linked runtime bridge
- separate embedding model install and lifecycle
- hardware proof of Gemma 4 tiers
- production model delivery for large artifacts
