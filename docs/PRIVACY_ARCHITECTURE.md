# Privacy Architecture

## Core boundary

Ross is built around a hard separation between:

1. `Case Vault`
2. `Local AI Runtime`
3. `Public Law Layer`
4. `Entitlement and Delivery Layer`

## Boundary rules

### Case Vault

Contains case metadata, documents, OCR text, chunks, embeddings, case memory, chat turns, exports, and local audit events.

- Must not import network clients
- Must not call entitlement services
- Must not expose raw case text to public-law search
- Mobile alpha stores case matters, documents, source refs, chat turns, exports, and ledger history in app-private local storage

### Local AI Runtime

Contains local-only chunking, retrieval, reranking, prompt building, output parsing, capability guards, and instant mode logic.

- Reads case vault data locally
- Must not call cloud LLM APIs
- Must not emit uncited outputs as authoritative facts

### Public Law Layer

Contains public query sanitization, user preview, proxy client, and local cache for public-law materials.

- Accepts only a sanitized query object
- Must not receive raw OCR text, chunks, filenames, case IDs, or chat history
- Every request is user-visible in the Privacy Ledger
- Mobile alpha performs a visible preview step before any outward search and stores only sanitized query cache items locally

### Entitlement and Delivery Layer

Contains auth, billing-linked entitlements, signed model catalogs, download sessions, and model pack lifecycle.

- Must not read case files
- Must not accept case-data payloads
- Every request is user-visible in the Privacy Ledger
- Mobile alpha persists model-download jobs, checksum state, install artifacts, and active-pack selection separately from case data

## Network allowlist

The production network layer is designed to allow only:

- `/auth/*`
- `/entitlements/*`
- `/model-catalog`
- `/model-download/*`
- `/billing/*`
- `/public-law/search`

All requests are classified as:

- `no_case_data`
- `account_token`
- `sanitized_public_query`

## Alpha implementation notes

- Android and iOS now persist case/document metadata in app-private local storage rather than keeping all case state in fixtures only.
- Imported files are copied into app-private storage before Ross creates document and page records.
- Source chips route into a document viewer using a local source-ref object with case, document, page, and snippet metadata.
- Model-pack install state is persisted locally with explicit states such as `queued`, `paused_waiting_for_wifi`, `verifying`, and `installed`.
- Development installs currently use a small local artifact for checksum and install-path plumbing; real segmented model delivery remains a later step.

## Logging limits

- No case text
- No OCR text
- No prompts
- No embeddings
- No filenames
- No party names
- No client names
- No case numbers
- No raw public search payloads in production logs
