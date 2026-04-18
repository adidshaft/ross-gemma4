# Model Registry

The onboarding flow shows only user-friendly capability tiers. Technical model names are reserved for internal evaluation, settings technical details, and engineering documentation.

## User-facing capability tiers

### Quick Start

- Basic document cleanup
- Short summaries
- Small-file case Q&A
- Basic chronology extraction

### Case Associate

- Source-backed case Q&A
- 50+ page PDF summarization
- Chronologies
- Issue extraction
- Order summaries
- Evidence matrix

### Senior Drafting Support

- Longer-document workflows
- Deeper issue and evidence analysis
- Better bilingual drafting support
- Senior counsel briefs
- Hearing preparation notes

## Hidden technical registry candidates

These are placeholders for packaging and evaluation only. The repo does not ship the model binaries.

- `gemma-4-e2b-q4`
  - candidate default local LLM
  - summaries, Q&A, chronology, issue extraction
- `gemma-4-e4b-q4`
  - stronger local LLM
  - longer files, richer drafting
- `embeddinggemma-300m-int8`
  - local embeddings
  - semantic search and local RAG
- `llama-3.2-3b-q4`
  - lower-end fallback
  - compact summarization and classification
- `qwen3-4b-thinking-q4`
  - experimental internal evaluation candidate
  - not enabled in onboarding

## Delivery principles

- Model files download after installation
- Downloads are signed, resumable, and checksum verified
- Apps remain usable without the full pack
- Technical details appear only under `Settings > Private AI > Technical Details`

## Alpha delivery notes

- Backend `/model-catalog` now returns tiny dev-artifact metadata for `Quick Start`, `Case Associate`, and `Senior Drafting Support`
- Backend `/model-download/session` now returns signed segment metadata with SHA-256 for each segment and the final artifact
- Backend `/dev-artifacts/:artifactId` serves range-request-friendly tiny dev artifacts so resumable delivery logic can be tested without shipping large binaries
- iOS alpha consumes the backend metadata path and verifies downloaded artifact bytes before marking a pack installed
- Android alpha currently preserves checksum-aware local dev artifact installs and privacy-safe payload shaping, but still needs runtime backend execution wiring
