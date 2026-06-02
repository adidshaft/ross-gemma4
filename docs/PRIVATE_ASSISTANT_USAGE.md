# Private Assistant Usage

Ross treats the Private AI Pack as the private assistant on this device.

Normal UI should show assistant levels and status, not technical model names.

## User-Facing Names

Use plain-language labels:

- Quick Start
- Case Associate
- Senior Drafting Support
- Private assistant
- Private AI Pack
- Basic local review
- Private assistant is ready
- Setting up private assistant
- Waiting for Wi-Fi
- Needs attention

Do not show Gemma 4, Q4, quantization, repository names, runtime names, checksums, or artifact names in normal screens.

## What The User Should Understand

When the private assistant is not ready:

- matters still work
- tasks and dates still work
- document import still works
- basic local review still works
- Ask Ross can still answer simple local questions when enough local case data exists

When the private assistant is ready:

- Ask Ross can run stronger local review
- Ross can shape public-law queries locally before preview
- source-backed answers use local retrieval
- private matter work remains on-device

## Tier Mapping

Quick Start:

- about 3.5 GB
- starts quickly with basic local review and simple Ask Ross actions

Case Associate:

- recommended
- about 5.4 GB
- best default for document review, chronologies, hearing notes, and source-backed answers

Senior Drafting Support:

- about 17.0 GB
- best for deeper review, longer matter reasoning, and drafting support

Matter Search:

- separate embedding model requirement
- supports local semantic search, source retrieval, and RAG
- not yet fully installed as a separate mobile lifecycle item

## Technical Details Boundary

These belong only under `Settings -> Advanced -> Support details` in debug builds or dedicated QA logs:

- technical model names
- repository names
- runtime modes
- artifact kinds
- checksums
- model file names
- provider failure categories
- local runtime paths

## Privacy Boundary

The private assistant may work with local matter data on-device.

It may not:

- send private matter content off-device
- call cloud AI for private matter data
- search public law without preview and user confirmation
- expose technical runtime detail in normal UI

Public-law search remains separate: only a confirmed sanitized public-law query may cross the boundary.

## Current Proof Status

Automated tests cover deterministic fallback, catalog metadata, tier labels, copy-boundary checks, downloaded-pack validation, unreadable-file handling, and Bengali/Hindi source-grounded local answers.

Observed on 2026-06-02:

- iOS simulator real GGUF smoke passed with `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime`.
- The smoke used `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf` and passed English, Bengali, Hindi, and general-answer checks.
- Live Hugging Face probes confirmed all configured assistant URLs resolve, linked ETags match pinned SHA-256 values, and one-byte range GETs return `206 Partial Content`.
- Swift tests passed for imported Bangla text becoming Ask-usable with a Bengali language hint.

Still not proven:

- real Q4 inference on Android
- physical iPhone download/resume/verify/activate and imported-file QA over a multi-GB GGUF
- separate embedding model download/install
- production large-model delivery under real network/storage interruption
