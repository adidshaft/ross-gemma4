# Offline Behavior

Ross is designed so legal work can continue even when no network is available.

The useful offline behavior is not only OCR. It is the combination of local text acquisition, local extraction, local verification, local review, and local exports.

## Works with no Private AI Pack installed

- create and manage cases locally
- import PDF, image, and text files into encrypted app-private storage
- acquire embedded PDF text locally where available
- run on-device OCR locally where available
- detect English, Hindi, and mixed-script documents locally
- run Basic extraction mode with deterministic heuristics
- review extracted details locally
- generate local chronology, case-note, and order-summary exports
- inspect the Privacy Ledger locally

## Works with Quick Start

- everything in Basic mode
- lighter prompt packing and local extraction orchestration for shorter documents
- conservative local classification and extraction improvements
- deterministic fallback if the runtime is unavailable or the source pack is too large

## Works with Case Associate

- everything in Quick Start
- deeper extraction and verifier chain
- stronger mixed-language handling
- review queues so the advocate only corrects uncertain fields
- optional real local inference when a compatible runtime is available and explicitly enabled for manual QA

## Works with Senior Drafting Support

- everything in Case Associate
- deeper synthesis planning for longer bundles
- stronger bilingual and multi-pass review behavior
- the same runtime safety rules and deterministic fallback behavior

## Requires network

- model catalog checks
- model-download session setup
- dev-artifact byte delivery for development pack installs
- entitlement refresh
- public-law search after the user approves the sanitized preview

## Degraded or waiting behavior

- If no pack is installed, Ross still remains useful for import, OCR, deterministic extraction, review, and export.
- If a real local runtime is configured but unavailable, Ross falls back safely to deterministic behavior.
- If a prompt pack is too large for the current runtime budget, Ross batches or falls back instead of crashing.
- If the backend is unavailable during development, already-imported case files remain local and accessible.
- Public-law search stays blocked until the user confirms the sanitized preview.

## Real local inference limits in this alpha

- No large model file is committed to the repo.
- No model file is bundled into the app.
- Android currently exposes compile-safe adapter skeletons only.
- iOS can use Apple Foundation Models when a compatible runtime is explicitly enabled.
- If no real runtime actually ran, Ross must not claim that it did.

## User-facing messaging

- Say when extraction quality is `Basic`, `Standard`, or `Advanced`.
- Show `Verified from source` and `Needs advocate review`.
- Keep `Case files stay on this device` explicit.
- Keep technical runtime status inside advanced or debug surfaces, not onboarding.
