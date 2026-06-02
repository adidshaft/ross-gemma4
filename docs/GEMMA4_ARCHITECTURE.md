# Gemma 4 Model Strategy

Ross uses a Gemma 4-first local generative stack for Private AI Pack tiers and a separate embedding model for local retrieval.

Normal product UI shows assistant levels, not model names. Technical names, repository names, runtime modes, checksums, and artifact details belong only under `Settings -> Advanced -> Support details` in debug builds or dedicated QA logs.

## Why Gemma 4 Q4

- Q4 gives Ross one practical local model packaging path across Android, iOS, desktop, and backend metadata.
- Gemma 4 has compact tiers that match Ross's private-assistant ladder without forcing a very large first download.
- `gemma_local_runtime` is the preferred generative runtime mode for the production-intended local stack.
- Deterministic development artifacts remain the CI and local-test default until a real model runtime is explicitly installed and proven.

## Assistant Tiers

| User tier | Technical model | Repo | Runtime | Download |
| --- | --- | --- | --- | --- |
| Flash | Gemma 4 E2B Q2 | `bartowski/google_gemma-4-E2B-it-GGUF` | `gemma_local_runtime` | about 3.0 GB |
| Quick Start | Gemma 4 E2B Q4 | `bartowski/google_gemma-4-E2B-it-GGUF` | `gemma_local_runtime` | about 3.5 GB |
| Case Associate | Gemma 4 E4B Q4 | `bartowski/google_gemma-4-E4B-it-GGUF` | `gemma_local_runtime` | about 5.4 GB |
| Senior Drafting Support | Gemma 4 26B-A4B Q4 | `bartowski/google_gemma-4-26B-A4B-it-GGUF` | `gemma_local_runtime` | about 17.0 GB |

Case Associate alternate repo: `google/gemma-4-E4B-it`.

Senior Drafting Support alternate official repo: `google/gemma-4-26B-A4B-it`.

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
- download: about 3.5 GB

Case Associate:

- minimum: 6-8 GB RAM
- recommended: 8-12 GB RAM
- download: about 5.4 GB

Senior Drafting Support:

- minimum: 8-12 GB RAM
- recommended: 12-16 GB RAM
- download: about 17.0 GB

Embedding model:

- minimum: 4-6 GB RAM
- recommended: 6-8 GB RAM

## Fallback Behavior

- `deterministic_dev` remains available for CI, unit tests, local fallback, and safe demo behavior.
- Backend `ROSS_MODEL_CATALOG_MODE=dev` serves tiny deterministic artifacts only.
- Backend `ROSS_MODEL_CATALOG_MODE=production_metadata` advertises Gemma 4 metadata but does not serve large model files unless a future delivery path is configured.
- If a real local runtime is unavailable, Ross falls back to basic local review and says so in plain language.

## Not Implemented Yet

- Production backend serving for real Q4 files.
- Automatic install and lifecycle management for the separate Matter Search embedding model.
- Android native Q4 inference.
- full physical-iPhone download/resume/verify/activate and imported-file QA with a configured multi-GB pack.
- Hardware proof of the full Gemma 4 stack on target devices.

No model files are committed, bundled, or downloaded into the repository.
