# Privacy Architecture

Ross is built around a hard local-first boundary for advocate case work.

The current product does not upload case files, OCR text, prompts, embeddings, filenames, party names, client facts, or extracted legal fields to cloud AI services.

## Core privacy promises

Ross keeps these product promises:

- `Case files stay on this device`
- `Draft for advocate review`
- `Source-backed`
- `Verified from source`
- `Needs review`
- `Public-law search sends only a sanitized query`

## Privacy layers

Ross separates work into four layers:

1. Case Vault
2. Local Review and Private AI
3. Public-law Search
4. Delivery and Entitlement

## Case Vault

The Case Vault contains:

- case metadata
- tasks
- reminders and dates
- imported documents
- extracted details
- review decisions
- source refs
- local exports
- privacy ledger entries

Rules:

- stays on device
- is not uploaded to cloud AI services
- is not shared with public-law search
- is not stored in analytics or telemetry systems

## Local Review and Private AI

This layer performs:

- local document reading
- OCR where supported locally
- source-backed extraction
- review queues
- case note and chronology generation
- local Ask Ross responses from case files

Rules:

- no cloud OCR
- no remote model APIs
- no analytics SDKs
- no silent case-data upload
- unsupported or uncertain details must remain reviewable, not silently accepted

## Public-law Search

This is the only legal-research network boundary in the normal app.

Rules:

- Web is off by default
- Ross must build the query locally
- Ross must show a preview before sending it
- Ross must require explicit confirmation
- Ross must send only a generic sanitized public-law query
- Ross must not send case text, filenames, party names, or factual narrative
- Ross must label public-law results separately from case-file sources

## Delivery and Entitlement

This layer covers:

- model catalog checks
- Private AI Pack downloads
- checksum verification
- install metadata
- entitlement checks

Rules:

- it must not read case files
- it must not receive case-data payloads
- it must not weaken the local-first boundary

## Privacy Ledger

The Privacy Ledger should remain understandable to a lawyer.

Examples of acceptable entries:

- `Checked Private AI availability`
- `Downloaded Private AI Pack`
- `Searched public law`
- `Generated local export`

The ledger should not expose raw payloads or raw private text.

## Real-runtime note

Real local model proof is separate from this usability alpha.

This architecture document describes the boundary Ross preserves now, regardless of whether a real on-device runtime has been separately proven in manual QA.
