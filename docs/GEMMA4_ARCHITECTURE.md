# Gemma 4 Product Architecture

Ross now uses a 3-pack Gemma 4-first local generative stack for the visible Private AI setup flow.

Normal product UI shows assistant levels, not model names. Technical names, repository names, runtime modes, checksums, and artifact details belong only under `Settings -> Advanced -> Support details` in debug builds or dedicated QA logs.

## Why Gemma 4 Q4

- Q4 gives Ross one practical local model packaging path across Android, iOS, desktop, and backend metadata.
- Gemma 4 now has a credible middle tier with the 12B instruct pack, which is a better default quality target than the older E2B/E4B-only ladder.
- `llama.cpp` through `llama.swift` is the active iOS GGUF runtime path today.
- Deterministic development artifacts remain the CI and local-test default until a real model runtime is explicitly installed and proven.

## Assistant Tiers

| User tier | Technical model | Repo | Runtime | Download |
| --- | --- | --- | --- | --- |
| Basic | Gemma 4 E4B Q4_K_M | `bartowski/google_gemma-4-E4B-it-GGUF` | `llama_cpp_gguf` | about 5.4 GB |
| Standard | Gemma 4 12B Q4_K_M | `ggml-org/gemma-4-12B-it-GGUF` | `llama_cpp_gguf` | about 7.4 GB |
| Advanced | Gemma 4 26B-A4B Q4_K_M | `bartowski/google_gemma-4-26B-A4B-it-GGUF` | `llama_cpp_gguf` | about 17.0 GB |

Standard alternate repo: `bartowski/gemma-4-12B-it-GGUF`.

Advanced alternate official repo: `google/gemma-4-26B-A4B-it`.

Legacy compatibility tier:

- Flash -> Gemma 4 E2B Q2
- kept only so older state can still decode cleanly
- not shown in the normal setup catalog

## Retrieval Model

Ross should not rely on the generative Gemma 4 model alone for retrieval.

Preferred retrieval model:

- Display name: Matter Search
- Technical model: EmbeddingGemma 300M
- Repo: `litert-community/embeddinggemma-300m`
- Runtime: `litert`
- Role: local semantic search, source retrieval, matter/document RAG, source-backed answers

Single-runtime fallback:

- Display name: Matter Search
- Technical model: Gemma 4-Embedding 0.6B Q4
- Repo: `google/gemma-4-embedding`
- Runtime: `gemma_local_runtime`
- Role: local semantic search and RAG retrieval through the Q4 runtime

## Hardware Estimates

Basic:

- minimum: 4-6 GB RAM phone
- recommended: 6-8 GB RAM
- download: about 5.4 GB

Standard:

- minimum: 6-8 GB RAM
- recommended: 8-12 GB RAM
- download: about 7.4 GB

Advanced:

- minimum: 8-12 GB RAM
- recommended: 12-18 GB RAM
- download: about 17.0 GB

Embedding model:

- minimum: 4-6 GB RAM
- recommended: 6-8 GB RAM

## Fallback Behavior

- `deterministic_dev` remains available for CI, unit tests, local fallback, and safe demo behavior.
- Backend `ROSS_MODEL_CATALOG_MODE=dev` serves tiny deterministic artifacts only.
- Backend `ROSS_MODEL_CATALOG_MODE=production_metadata` advertises Gemma 4 metadata but does not serve large model files unless a future delivery path is configured.
- If a real local runtime is unavailable, Ross falls back to basic local review and says so in plain language.

## iPhone Runtime Notes

- `ios/Package.swift` now pins `llama.swift` with `.upToNextMajor(from: "2.9637.0")`.
- `ios/Package.resolved` currently resolves commit `d159d5ccf8fc8a3c55c05a72980f3c94ad91f734`.
- Context windows now scale by pack and device RAM:
  - Basic: 8k to 12k tokens
  - Standard: 12k to 16k tokens
  - Advanced: 8k to 12k tokens
- Input budgets are widened per tier so longer matter files can stay on-device instead of being truncated to the old fixed limits.

## Not Implemented Yet

- Production backend serving for real Q4 files.
- Automatic install and lifecycle management for the separate Matter Search embedding model.
- Android native Q4 inference.
- full physical-iPhone download/resume/verify/activate and imported-file QA with the 12B pack.
- Hardware proof of the full Gemma 4 stack on target devices.
- MLX-native iPhone experiments for cases where converted Gemma 4 weights may outperform GGUF.

No model files are committed, bundled, or downloaded into the repository.
