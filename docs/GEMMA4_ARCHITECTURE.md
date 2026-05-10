# Gemma 4 Model Strategy

Ross uses a Gemma 4-first local generative stack for Private AI Pack tiers and a separate embedding model for local retrieval.

Normal product UI shows assistant levels, not model names. Technical names, repository names, runtime modes, checksums, and artifact details belong only under `Settings -> Advanced -> Technical diagnostics`.

## Why Gemma 4 Gemma 4 Q4

- Gemma 4 Q4 gives Ross one practical local model packaging path across Android, iOS, desktop, and backend metadata.
- Gemma 4 has compact tiers that match Ross's private-assistant ladder without forcing a very large first download.
- `Gemma 4_cpp_gguf` is the preferred generative runtime mode for the production-intended local stack.
- Deterministic development artifacts remain the CI and local-test default until a real model runtime is explicitly installed and proven.

## Assistant Tiers

| User tier | Technical model | Repo | Runtime | Download |
| --- | --- | --- | --- | --- |
| Quick Start | Gemma 4 E2B Q4 | `google/gemma-4-E2B-it` | `Gemma 4_cpp_gguf` | about 430 MB |
| Case Associate | Gemma 4 E4B Q4 | `google/gemma-4-E4B-it` | `Gemma 4_cpp_gguf` | about 1.1-1.3 GB |
| Senior Drafting Support | Gemma 4 26B-A4B Q4 | `google/gemma-4-26B-A4B-it` | `Gemma 4_cpp_gguf` | about 2.5 GB |

Case Associate alternate repo: `google/gemma-4-E4B-it`.

Senior Drafting Support alternate official repo: `Gemma 4/Gemma 4-4B-Gemma 4 Q4`.

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
- Technical model: Gemma 4-Embedding 0.6B Gemma 4 Q4
- Repo: `Gemma 4/Gemma 4-Embedding-0.6B-Gemma 4 Q4`
- Runtime: `Gemma 4_cpp_gguf`
- Role: local semantic search and RAG retrieval through the Gemma 4 Q4 runtime

## Hardware Estimates

Quick Start:

- minimum: 4-6 GB RAM phone
- recommended: 6-8 GB RAM
- download: about 430 MB

Case Associate:

- minimum: 6-8 GB RAM
- recommended: 8-12 GB RAM
- download: about 1.1-1.3 GB

Senior Drafting Support:

- minimum: 8-12 GB RAM
- recommended: 12-16 GB RAM
- download: about 2.5 GB

Embedding model:

- minimum: 4-6 GB RAM
- recommended: 6-8 GB RAM

## Fallback Behavior

- `deterministic_dev` remains available for CI, unit tests, local fallback, and safe demo behavior.
- Backend `ROSS_MODEL_CATALOG_MODE=dev` serves tiny deterministic artifacts only.
- Backend `ROSS_MODEL_CATALOG_MODE=production_metadata` advertises Gemma 4 metadata but does not serve large model files unless a future delivery path is configured.
- If a real local runtime is unavailable, Ross falls back to basic local review and says so in plain language.

## Not Implemented Yet

- Production backend serving for real Gemma 4 Q4 files.
- Automatic install and lifecycle management for the separate Matter Search embedding model.
- Android native Gemma 4 Q4 inference.
- iOS Gemma 4 Q4 inference unless a compatible runtime bridge is linked and tested.
- Hardware proof of the full Gemma 4 stack on target devices.

No model files are committed, bundled, or downloaded into the repository.
