# Privacy Architecture

Ross is built around a hard local-first boundary for advocate case work. The active product does not upload case files, OCR text, prompts, embeddings, filenames, party names, client facts, or extracted legal fields to cloud AI services.

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
- chat turns
- exports
- local privacy ledger history

Rules:

- Must stay local to the device.
- Must not import cloud inference clients.
- Must not send raw case text to public-law search.
- Must not expose prompts, OCR text, embeddings, or filenames across the network boundary.

Alpha storage status:

- Android alpha encrypts persisted state at rest with Keystore-backed AES-GCM.
- iOS alpha encrypts persisted state at rest with Keychain-managed AES.GCM.
- Legacy plaintext alpha state is migrated locally and then removed after successful encrypted save.

## Local Extraction and AI Runtime

This layer performs law-grade document understanding locally.

It includes:

- text acquisition
- OCR cleanup
- English/Hindi/mixed language heuristics
- script detection
- layout-aware segmentation
- document classification
- legal field extraction
- verifier/refiner pass
- confidence scoring
- advocate review queues
- case-memory synthesis
- local chunking, retrieval, and drafting support

Rules:

- OCR is acquisition, not reasoning.
- No cloud LLM APIs.
- No cloud OCR.
- No analytics or telemetry SDKs.
- Uploaded documents are treated as data, not instructions.
- Every extracted value must keep source support.
- Unsupported or weakly supported values must be marked `needs review`, not silently accepted.
- Synthesis must stay grounded in the same local sources that produced the candidate fields.

Runtime status:

- The active alpha uses deterministic development runtime behavior plus platform stubs where a real local model is not bundled.
- The architecture is prepared for a true on-device inference adapter, but orchestration interfaces alone are not proof that a local LLM is already running.

## Public Law Layer

The Public Law Layer is the only outward-facing legal research boundary.

It contains:

- local sanitization
- preview/confirmation UI
- approved backend client
- local cache of approved public-law results

Rules:

- Accepts only a sanitized public query object.
- Must not receive case IDs, filenames, OCR text, extracted field values, party names, or client facts.
- Requires explicit user confirmation before a network request.
- Every request is visible in the Privacy Ledger.
- The backend rejects unsafe/private queries and avoids raw-query logging in protected paths.

Ross may propose a public-law query locally from extracted legal concepts, but the preview remains mandatory.

## Entitlement and Delivery Layer

This layer contains:

- auth/account token handling
- entitlements
- model catalog
- model-download session setup
- byte-range dev-artifact delivery
- checksum verification
- pack install metadata

Rules:

- Must not read case files.
- Must not accept case-data payloads.
- Must remain limited to `no_case_data`, `account_token`, or `sanitized_public_query` payload classes.
- Every request is visible in the Privacy Ledger.

Alpha status:

- Backend `/model-catalog` returns signed tiny dev-artifact metadata.
- Backend `/model-download/session` returns signed segment metadata.
- Backend `/dev-artifacts/:artifactId` supports byte ranges for resumable development installs.
- Android and iOS alpha shells both shape and use privacy-safe backend payloads for model delivery and public-law search.

## Boundary summary

- Case data stays local.
- OCR stays local.
- Extraction is local-first and source-backed.
- Model delivery is separate from case data.
- Public-law search is separate from private-case extraction.
- Development runtime validation is not the same thing as a bundled production local model.

## Network allowlist

The intended network surface stays restricted to:

- `/auth/*`
- `/entitlements/*`
- `/model-catalog`
- `/model-download/*`
- `/billing/*`
- `/public-law/search`
- `/dev-artifacts/*`

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
