# Model Registry

Ross shows advocate-friendly assistant levels in normal UI. Technical model names stay under `Settings -> Advanced -> Support details` in debug builds or dedicated QA logs.

## Canonical Files

- `shared/constants/privateAssistantModelRegistry.json`
- `shared/constants/modelCapabilityTiers.json`
- `shared/constants/technicalModelRegistry.json`
- `backend/src/model_catalog/service.ts`
- `core/rust/src/ai_capability.rs`

## Recommended Stack

Visible generative assistant tiers are Gemma 4-first:

- Quick Start -> `gemma-4-e4b-q4`, `unsloth/gemma-4-E4B-it-qat-GGUF`
- Case Associate -> `gemma-4-12b-q4`, `unsloth/gemma-4-12B-it-qat-GGUF`
- Senior Drafting Support -> `gemma-4-26b-a4b-q4`, `unsloth/gemma-4-26B-A4B-it-qat-GGUF`

Retrieval is separate:

- preferred: EmbeddingGemma 300M, `litert-community/embeddinggemma-300m`, `litert`
- fallback: Gemma 4-Embedding 0.6B Q4, `google/gemma-4-embedding`, `gemma_local_runtime`

Gemma/Gemma 3n generative paths are optional future or experimental paths, not Ross's default Private AI Pack strategy.

## User-Facing Packs

### No assistant installed

- available with no Private AI Pack installed
- uses local acquisition, OCR where available, heuristics, and deterministic extraction

### Quick Start

- download: about 4.3 GB in the current iOS catalog
- role: lighter everyday work, short summaries, and quicker local matter Q&A
- runtime priority: GGUF on all supported platforms, with MLX and CoreAI eligible on supported iPhones

### Case Associate

- recommended
- download: about 7.0 GB in the current iOS catalog
- role: most matters, larger files, chronology work, hearing notes, and source-backed Ask Ross answers
- runtime priority: GGUF by default, with MLX preferred on supported iPhones when it remains the faster lane

### Senior Drafting Support

- download: about 14.5 GB in the current iOS catalog
- role: larger bundles, deeper review, longer local reasoning, chronology refinement, and drafting support
- runtime priority: GGUF first, with CoreAI eligible where instant built-in setup is preferred

### Legacy compatibility tier

- Flash remains decodable for older state and tests
- it is not shown in the normal setup catalog
- it is not part of the shipped visible 3-pack ladder

## Runtime And Artifact Values

Supported runtime-mode values:

- `deterministic_dev`
- `mediapipe_llm`
- `gemma_local_runtime`
- `mlx_swift_lm`
- `apple_foundation_models`
- `unavailable`

Supported artifact-kind values:

- `tiny_dev_artifact`
- `local_model_artifact`
- `mlx_directory`
- `system_model`
- `external_debug_model`

## Backend Catalog Modes

`ROSS_MODEL_CATALOG_MODE=dev`:

- default for CI and local development
- serves only tiny deterministic artifacts
- keeps `deterministic_dev` stable

`ROSS_MODEL_CATALOG_MODE=production_metadata`:

- advertises Gemma 4 tier metadata
- uses `local_model_artifact`
- uses the current GGUF runner slot (`gemma_local_runtime`)
- does not provide real download URLs or segments
- rejects model download sessions until a real delivery path is configured

## Registry Principles

- no model files are committed
- no large model files are bundled into app assets
- normal UI uses assistant levels, not model names
- private matter data never goes to cloud AI
- deterministic dev remains available for tests and fallback
- iPhone runtime selection may choose GGUF, MLX, or built-in CoreAI depending on support and recent performance
- source-backed answers require the separate retrieval model path
