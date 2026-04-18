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

### Entitlement and Delivery Layer

Contains auth, billing-linked entitlements, signed model catalogs, download sessions, and model pack lifecycle.

- Must not read case files
- Must not accept case-data payloads
- Every request is user-visible in the Privacy Ledger

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

