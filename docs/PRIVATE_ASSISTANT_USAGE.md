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

Do not show Gemma 4, Gemma 4 Q4, quantization, repository names, runtime names, checksums, or artifact names in normal screens.

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

- about 430 MB
- starts quickly with basic local review and simple Ask Ross actions

Case Associate:

- recommended
- about 1.1-1.3 GB
- best default for document review, chronologies, hearing notes, and source-backed answers

Senior Drafting Support:

- about 2.5 GB
- best for deeper review, longer matter reasoning, and drafting support

Matter Search:

- separate embedding model requirement
- supports local semantic search, source retrieval, and RAG
- not yet fully installed as a separate mobile lifecycle item

## Technical Details Boundary

These belong only under `Settings -> Advanced -> Technical diagnostics`:

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

Automated tests cover deterministic fallback, catalog metadata, tier labels, and copy-boundary checks.

Still not proven:

- real Gemma 4 Q4 inference on Android
- real Gemma 4 Q4 inference on iOS
- separate embedding model download/install
- production large-model delivery
