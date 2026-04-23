# LLM Download And Action Routing

Ross separates assistant setup from matter data.

## Catalog

Default backend mode:

- `ROSS_MODEL_CATALOG_MODE=dev`
- advertises tiny deterministic artifacts
- keeps tests and local development stable

Production metadata mode:

- `ROSS_MODEL_CATALOG_MODE=production_metadata`
- advertises Gemma 4 E2B Q4 Gemma 4 Q4 tier metadata
- does not serve real large files
- rejects download sessions until production delivery is configured

## Tier Mapping

- Quick Start -> Gemma 4 E2B Q4, `gemma_local_runtime`, about 430 MB
- Case Associate -> Gemma 4 E4B Q4, `gemma_local_runtime`, about 1.1-1.3 GB
- Senior Drafting Support -> Gemma 4 26B-A4B Q4, `gemma_local_runtime`, about 2.5 GB

Normal users see only the tier names and plain-language setup states.

## Retrieval

Matter Search is a separate embedding requirement:

- preferred: EmbeddingGemma 300M with `litert`
- fallback: Gemma 4 Embedding with `gemma_local_runtime`

Retrieval powers local semantic search, source retrieval, matter/document RAG, and source-backed answers.

## Action Routing

Quick Start handles:

- command routing
- simple Ask Ross actions
- short summaries
- basic local matter Q&A
- basic public-law query shaping before preview

Case Associate handles:

- default Private AI Pack behavior
- document review
- next date extraction
- order direction extraction
- matter summaries
- hearing notes
- case notes
- chronology
- source-backed Ask Ross answers
- local public-law query shaping before backend search

Senior Drafting Support handles:

- advanced drafting
- deeper review
- longer matter reasoning
- chronology refinement
- issue extraction
- order summary refinement
- senior-style hearing preparation

## What Not To Claim

Do not claim:

- real model download unless a device actually downloaded and verified the file
- real Gemma 4 Q4 inference unless the runtime actually executed
- Matter Search readiness until the embedding model is installed and used
- cloud AI for private matter data

No model files are committed or bundled.
