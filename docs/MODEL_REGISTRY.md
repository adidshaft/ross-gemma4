# Model Registry

Ross shows advocate-friendly assistant levels in normal UI. Technical model names stay under `Settings -> Advanced -> Technical diagnostics`.

## Canonical Files

- `shared/constants/privateAssistantModelRegistry.json`
- `shared/constants/modelCapabilityTiers.json`
- `shared/constants/technicalModelRegistry.json`
- `backend/src/model_catalog/service.ts`
- `core/rust/src/ai_capability.rs`

## Recommended Stack

Generative assistant tiers are Gemma 4-first:

- Quick Start -> Gemma 4 E2B Q4, `google/gemma-4-E2B-it`
- Case Associate -> Gemma 4 E4B Q4, `google/gemma-4-E4B-it`
- Senior Drafting Support -> Gemma 4 26B-A4B Q4, `google/gemma-4-26B-A4B-it`

Retrieval is separate:

- preferred: EmbeddingGemma 300M, `litert-community/embeddinggemma-300m`, `litert`
- fallback: Gemma 4-Embedding 0.6B Gemma 4 Q4, `Gemma 4/Gemma 4-Embedding-0.6B-Gemma 4 Q4`, `Gemma 4_cpp_gguf`

Gemma/Gemma 3n generative paths are optional future or experimental paths, not Ross's default Private AI Pack strategy.

## User-Facing Packs

### Basic

- available with no Private AI Pack installed
- uses local acquisition, OCR where available, heuristics, and deterministic extraction

### Quick Start

- download: about 430 MB
- role: command routing, simple Ask Ross actions, short summaries, basic local matter Q&A

### Case Associate

- recommended
- download: about 1.1-1.3 GB
- role: document review, next-date extraction, order directions, matter summaries, hearing notes, chronology, source-backed Ask Ross answers

### Senior Drafting Support

- download: about 2.5 GB
- role: advanced drafting, deeper review, longer matter reasoning, chronology refinement, issue extraction, hearing preparation

## Runtime And Artifact Values

Supported runtime-mode values:

- `deterministic_dev`
- `mediapipe_llm`
- `Gemma 4_cpp_gguf`
- `apple_foundation_models`
- `litert`
- `unavailable`

Supported artifact-kind values:

- `tiny_dev_artifact`
- `local_model_artifact`
- `local_embedding_model`
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
- uses `Gemma 4_cpp_gguf`
- does not provide real download URLs or segments
- rejects model download sessions until a real delivery path is configured

## Registry Principles

- no model files are committed
- no large model files are bundled into app assets
- normal UI uses assistant levels, not model names
- private matter data never goes to cloud AI
- deterministic dev remains available for tests and fallback
- source-backed answers require the separate retrieval model path
