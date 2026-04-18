# Privacy Architecture

Ross is built around a hard local-first boundary for advocate case work.

The active product does not upload case files, OCR text, prompts, embeddings, filenames, party names, client facts, or extracted legal fields to cloud AI services.

## Core boundary

Ross separates work into four layers:

1. `Case Vault`
2. `Local Extraction and AI Runtime`
3. `Public Law Layer`
4. `Entitlement and Delivery Layer`

## Case Vault

The Case Vault contains:

- case metadata
- imported files
- page text and OCR results
- source refs
- extracted legal fields
- extraction runs and findings
- advocate corrections
- case memory updates
- local exports
- local privacy ledger history

Rules:

- stays local to the device
- never imports network inference clients
- never sends raw case text to public-law search
- never exposes prompts, OCR text, embeddings, or filenames across the network boundary

## Local Extraction and AI Runtime

This layer performs law-grade document understanding locally.

It includes:

- text acquisition
- OCR cleanup
- language and script detection
- prompt packing
- document classification
- legal field extraction
- verifier/refiner pass
- confidence scoring
- advocate review queues
- case-memory synthesis

Rules:

- OCR is acquisition, not reasoning
- no cloud model calls
- no cloud OCR
- no analytics or telemetry SDKs
- uploaded documents are treated as data, not instructions
- every accepted value must keep source support
- unsupported values must become `needs review` or `rejected`
- the runtime itself must not use the network

Runtime status in this alpha:

- deterministic development runtime is active and real
- Android real-runtime adapters are scaffolded but unavailable
- iOS has a real Apple Foundation Models adapter path behind explicit developer opt-in
- raw prompts and raw source text are not persisted in invocation metadata by default

## Public Law Layer

The Public Law Layer is the only outward-facing legal research boundary.

It contains:

- local sanitization
- preview and confirmation UI
- approved backend client
- local cache of approved public-law results

Rules:

- accepts only sanitized public query objects
- never receives case IDs, filenames, OCR text, party names, client facts, or raw extracted values
- requires explicit user confirmation before a network request
- logs only sanitized public query activity in the Privacy Ledger

Ross may suggest a public-law query from extracted legal concepts, but the preview remains mandatory.

## Entitlement and Delivery Layer

This layer contains:

- auth and entitlement handling
- model catalog
- model-download session setup
- byte-range development artifact delivery
- checksum verification
- pack install metadata

Rules:

- must not read case files
- must not accept case-data payloads
- remains limited to `no_case_data`, `account_token`, or `sanitized_public_query` payload classes

Alpha status:

- backend model catalog and download flows remain dev-artifact only
- delivery metadata now includes runtime mode, artifact kind, and minimum app-version compatibility fields
- no large model file is stored in source control or served as part of the normal alpha flow

## Logging limits

The following must never appear in backend logs or outbound payloads:

- case text
- OCR text
- prompts
- embeddings
- filenames
- party names
- client names
- case numbers
- private extracted fields
- fake privacy regression strings used in tests

Those values may appear only in encrypted local storage, local review UI, local viewer context, and local source-backed exports.
