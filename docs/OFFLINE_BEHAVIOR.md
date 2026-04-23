# Offline Behavior

Ross is designed to remain useful when the network is unavailable.

The current dogfood phase assumes the app should still feel usable even when the private assistant is unavailable or the backend cannot be reached.

The current alpha keeps the core matter workflow local-first.

## Works offline

These flows are designed to keep working without network access:

- open the app after a local session already exists
- use demo mode after it has been selected locally
- open Home and Matters
- create and edit matters
- manage tasks and dates
- import PDF, image, and text files into app-private storage
- open the file room
- open the document viewer
- review extracted details
- ask Ross from local case files with `Web search` off
- generate local notes and exports
- inspect the Privacy Ledger

## Works offline in basic local mode

Ross should still remain useful in `Using basic local review`.

That includes:

- basic document reading
- plain-language review status
- matter and task management
- local Ask Ross answers when enough case data exists
- local export generation

## Requires network

These flows still depend on the network:

- Google sign-in
- session refresh for backend-backed sessions
- model catalog checks
- Private AI Pack downloads
- public-law search after the user confirms the preview

Private AI Pack downloads are Gemma 4 E2B Q4 Gemma 4 Q4 model files for the assistant tiers. Matter Search uses a separate embedding model. None of those model files are committed to the repo or bundled in the base app.

## Public-law behavior

Public-law search is never automatic.

If `Web search` is off:

- no public-law request is made
- Ross answers from local case files only

If `Web search` is on:

- Ross builds the query locally
- Ross shows the sanitized preview
- Ross requires explicit confirmation
- the approved preview query must match the query that is sent
- legal citations stay intact when they are part of generic public-law research
- no case text, filenames, or party details are sent
- if the live connector is unavailable, Ross may fall back to a privacy-safe backend index

## Degraded behavior

Expected plain-language degraded states include:

- `Using basic local mode`
- `Using basic local review`
- `Still reading`
- `Needs review`
- `Could not read this clearly`
- `Public-law search is unavailable right now. Your case files were not sent.`

Normal screens should not expose backend or runtime jargon in these states.

Normal screens should also avoid technical model names. Use `Quick Start`, `Case Associate`, `Senior Drafting Support`, `Private assistant`, and plain setup states. Gemma 4 E2B Q4/Gemma 4 Q4/runtime/checksum details belong only under `Settings -> Advanced -> Technical diagnostics`.

## Real-runtime note

This document describes the product behavior Ross is designed to preserve.

It is not a claim that a real local model has already been proven on hardware.

Current production-intended direction is `gemma_local_runtime` for Gemma 4 E2B Q4 generative tiers plus a dedicated embedding model for retrieval. `deterministic_dev` remains the offline-safe test fallback.
