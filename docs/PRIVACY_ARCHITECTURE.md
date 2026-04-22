# Privacy Architecture

Ross is built around a hard local-first boundary for advocate case work.

The product does not upload case files, OCR text, prompts, embeddings, filenames, party names, client facts, or extracted legal fields to cloud AI services.

## Core privacy promises

Ross keeps these product promises:

- `Case files stay on this device`
- `Draft for advocate review`
- `Source-backed`
- `Verified from source`
- `Needs review`
- `Public-law search sends only a sanitized query`

## Privacy layers

Ross separates work into five layers:

1. Case Vault
2. Local Review and Ask Ross
3. Public-law Search
4. Auth and Session
5. Delivery and Entitlement

## Case Vault

The Case Vault contains:

- matter metadata
- tasks and dates
- imported documents
- extracted details
- review decisions
- source references
- local exports
- privacy ledger entries

Rules:

- stays on device
- is not uploaded to cloud AI services
- is not shared with public-law search
- is not stored in analytics or telemetry systems

## Local Review and Ask Ross

This layer performs:

- local document reading
- source-backed extraction
- review queues
- chronology and note drafting
- local Ask Ross responses from case files

Rules:

- no cloud OCR
- no remote model APIs
- no analytics SDKs
- no silent case-data upload
- unsupported or uncertain details remain reviewable

## Public-law Search

This is the only normal user network boundary for legal research.

Rules:

- Web is off by default
- Ross must build the query locally
- Ross must show a preview before sending it
- Ross must require explicit confirmation
- Ross must send only a generic sanitized public-law query
- Ross must reject private details such as party names, filing references, exact dates, filenames, and factual narratives
- Ross must label public-law results separately from case-file sources

The current development backend returns privacy-safe fixture results for QA. That is still subject to the same boundary.

When a live connector is enabled, it must remain server-side only. The current connector path is Gemini with Google Search grounding behind the same preview-confirmation boundary. Only the sanitized public-law query may cross that boundary.

## Auth and Session

Auth is separate from matter content.

Rules:

- auth routes must not receive case-file payloads
- refresh and account tokens must not contain case text
- audit logs must not contain raw prompts or raw source text
- Google sign-in must remain plain-language in the app on failure
- Apple sign-in is currently local-session only on iOS

## Delivery and Entitlement

This layer covers:

- model catalog checks
- Private AI Pack downloads
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

The ledger should not expose raw payloads, raw prompts, or raw private text.

## Regression guardrail

Fake-secret regression values such as `Raghav Fakepriv`, `9876501234`, `fakepriv@example.com`, `FAKE/123/2026`, and `blue suitcase near temple` may appear in local-only UI, but must not cross the public-law or auth boundary.

## Real-runtime note

This architecture document describes the privacy boundary Ross preserves in the current internal alpha.

It is not a claim that a real local model has already been proven on hardware.
