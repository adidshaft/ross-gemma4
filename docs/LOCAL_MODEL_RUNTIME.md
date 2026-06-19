# Local Model Runtime

Ross uses a local runtime contract so private matter work can improve without weakening the privacy boundary.

## Current Direction

- Gemma 4 Q4 is the production-intended generative model stack for Private AI Pack tiers.
- `gemma_local_runtime` is the preferred local generative runtime mode.
- Matter/document retrieval uses a separate embedding model. The preferred path is EmbeddingGemma 300M with `litert`; the single-runtime fallback is Gemma 4-Embedding 0.6B Q4.
- `deterministic_dev` remains the default fallback for CI, tests, and local development.
- No model files are committed or bundled.

## Runtime Modes

Ross runtime metadata supports:

- `deterministic_dev`
- `mediapipe_llm`
- `gemma_local_runtime`
- `mlx_swift_lm`
- `apple_foundation_models`
- `litert`
- `unavailable`

Artifact metadata supports:

- `tiny_dev_artifact`
- `local_model_artifact`
- `local_embedding_model`
- `mlx_directory`
- `system_model`
- `foundation_adapter`
- `coreai_adapter`
- `coreml_model`
- `external_debug_model`

## Provider Behavior

Deterministic development provider:

- default for CI and tests
- network-free
- schema-shaped
- not a real model proof

Q4 provider direction:

- primary target for Gemma 4 generative tiers
- selected through `gemma_local_runtime`
- must load files only from app-private storage or explicit external/dev paths
- must not bundle Q4 files into the app

Retrieval provider direction:

- separate from the generative Gemma 4 model
- powers Matter Search, local semantic search, source retrieval, matter/document RAG, and source-backed answers
- preferred runtime is `litert`
- fallback runtime is `gemma_local_runtime`

Existing compatibility:

- Android still has a MediaPipe adapter path for explicitly supplied developer artifacts.
- iOS still has an on-device system assistant path where available.
- Both remain compatibility paths, not the default Gemma 4-first strategy.

## Runtime Proof Guardrails

Real-runtime benchmarks must be tied to the app's `ROSS_RUNTIME_IDENTITY` marker, not just a smoke pass line. The marker records requested runtime, actual provider runtime, artifact kind/path type, acceleration mode, draft model metadata, `draft_status`, context size, GPU/offload summary, fallback status, and availability.

Do not publish MLX, CoreAI/Foundation Models, or MTP numbers unless the identity marker proves that exact lane:

- MLX requires `actual_runtime=mlx_swift_lm`.
- CoreAI/Foundation Models requires `actual_runtime=apple_foundation_models`.
- MTP requires identity `acceleration=draftModelSpeculative`, `draft_status=active`, non-empty draft tokens, and draft model metadata. Smoke benchmark summaries must also prove every matrix stage used draft acceleration with matching `*_acceleration`, `*_draft_tokens`, and `*_draft_model` fields.
- Benchmark summaries must also prove the pass runtime matches a known benchmark lane, matches identity `actual_runtime`, identity `requested_runtime` does not disagree, every matrix stage is one of the supported smoke stages, and every matrix stage reports token count, token speed, first-token latency, and measured/estimated status.
- Any fallback to `gemma_local_runtime`, `deterministic_dev`, or `unavailable` invalidates the requested lane's benchmark.
- In required draft-acceleration smoke mode, MLX speculative generation failure is reported as `mlx_draft_generation_failed` instead of retrying standard generation, so a draft-proof run cannot publish standard MLX numbers.

Installed-pack validation is runtime-specific before reuse:

- GGUF packs require `local_model_artifact`; MTP draft companions must be `.gguf` local-model artifacts.
- MLX packs and MLX draft companions require `mlx_directory` and a usable MLX directory shape.
- CoreAI/CoreML/Foundation adapters require adapter artifact kinds; built-in `system_model` is reserved for system sentinel paths.

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
- iOS GGUF/llama.cpp execution has physical-device proof for the constrained Quick Start lane
- smoke-time runtime identity reporting and guardrails for requested-vs-actual runtime validation

Not yet proven:

- Android native Q4 inference
- MLX and CoreAI/Foundation Models generation on physical iPhone without routing through GGUF
- MTP draft acceleration on physical iPhone
- separate embedding model install and lifecycle
- hardware proof of every visible Gemma 4 tier
- production model delivery for large artifacts
