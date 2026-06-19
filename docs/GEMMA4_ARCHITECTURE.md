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
| Quick Start | Gemma 4 E4B UD Q4_K_XL | `unsloth/gemma-4-E4B-it-GGUF` | `gemma_local_runtime` | about 5.2 GB |
| Case Associate | Gemma 4 12B UD Q4_K_XL | `unsloth/gemma-4-12b-it-GGUF` | `gemma_local_runtime` | about 7.8 GB |
| Senior Drafting Support | Gemma 4 26B-A4B UD Q4_K_XL | `unsloth/gemma-4-26B-A4B-it-GGUF` | `gemma_local_runtime` | about 17.5 GB |

Quick Start and Case Associate GGUF packs also carry official MTP draft companions in the configured lineup. Senior Drafting Support also keeps an MTP draft companion, but it is still treated as the heaviest local path.

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

Quick Start:

- minimum: 4-6 GB RAM phone
- recommended: 6-8 GB RAM
- download: about 5.2 GB

Case Associate:

- minimum: 6-8 GB RAM
- recommended: 8-12 GB RAM
- download: about 7.8 GB

Senior Drafting Support:

- minimum: 8-12 GB RAM
- recommended: 12-18 GB RAM
- download: about 17.5 GB

Embedding model:

- minimum: 4-6 GB RAM
- recommended: 6-8 GB RAM

## Fallback Behavior

- `deterministic_dev` remains available for CI, unit tests, local fallback, and safe demo behavior.
- Backend `ROSS_MODEL_CATALOG_MODE=dev` serves tiny deterministic artifacts only.
- Backend `ROSS_MODEL_CATALOG_MODE=production_metadata` advertises Gemma 4 metadata but does not serve large model files unless a future delivery path is configured.
- If a real local runtime is unavailable, Ross falls back to basic local review and says so in plain language.

## iPhone Runtime Notes

- `ios/Package.swift` now pins `llama.swift` with `.upToNextMajor(from: "2.9672.0")`.
- The visible GGUF ladder now points at the newer Unsloth QAT repos while keeping MTP draft heads enabled.
- `ios/Package.resolved` currently resolves commit `c3e6e06277638dc253c1e2f0ea52aab225343548`.
- Context windows now scale by pack and device RAM:
  - Quick Start: about 10k to 20k tokens
  - Case Associate: about 20k to 40k tokens on capable iPhones
  - Senior Drafting Support: about 10k to 24k tokens
- Input budgets are widened per tier so longer matter files can stay on-device instead of being truncated to the old fixed limits.
- Supported iPhone runtime selection can choose GGUF, MLX, or built-in CoreAI depending on device support and recent runtime performance, but MLX/CoreAI benchmark claims require their own matching `ROSS_RUNTIME_IDENTITY` and successful generation.
- MLX is currently wired only for the visible Quick Start and Case Associate tiers; Senior Drafting Support remains GGUF/CoreAI-only because the current 26B-A4B MLX main archive is still blocked. The MLX lane is not physical-benchmark-proven until the installed MLX directory generates under `actual_runtime=mlx_swift_lm`.

## Not Implemented Yet

- Production backend serving for real Q4 files.
- Automatic install and lifecycle management for the separate Matter Search embedding model.
- Android native Q4 inference.
- full physical-iPhone download/resume/verify/activate and imported-file QA with the 12B pack.
- Hardware proof of the full Gemma 4 stack on target devices.
- Full physical-iPhone proof for the MLX and CoreAI runtime lanes.

No model files are committed, bundled, or downloaded into the repository.
