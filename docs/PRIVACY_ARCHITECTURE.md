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
- Android alpha state is encrypted at rest with Keystore-backed AES-GCM
- iOS alpha state is encrypted at rest with Keychain-managed AES.GCM
- Legacy plaintext alpha state is migrated locally and deleted after successful encrypted save

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
- Backend `/public-law/search` rejects unsafe/private queries and never logs raw query text in production mode
- Active Android alpha UI still uses local execution stubs after preview confirmation; iOS alpha now includes a backend client for the hardened route

### Entitlement and Delivery Layer

Contains auth, billing-linked entitlements, signed model catalogs, download sessions, and model pack lifecycle.

- Must not read case files
- Must not accept case-data payloads
- Every request is user-visible in the Privacy Ledger
- Mobile alpha persists model-download jobs, checksum state, install artifacts, and active-pack selection separately from case data
- Backend now serves tiny dev artifacts with range support at `/dev-artifacts/:artifactId` so resumable download logic can be exercised without bundling model files
- Model catalog and model-download session payloads remain `no_case_data` or `account_token` only

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

- Android and iOS now persist case/document metadata in encrypted app-private local storage rather than keeping all case state in fixtures only.
- Imported files are copied into app-private storage before Ross creates document and page records.
- Source chips route into a document viewer using a local source-ref object with case, document, page, and snippet metadata.
- Model-pack install state is persisted locally with explicit states such as `queued`, `paused_waiting_for_wifi`, `verifying`, and `installed`.
- iOS alpha can fetch signed catalog/session metadata and segmented dev-artifact bytes from the backend, then verifies and stores the artifact locally.
- Android alpha currently stops at privacy-safe payload shaping, persistence, and checksum plumbing; full runtime backend wiring remains the next step.

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
- No plaintext state files left behind after encrypted migration
