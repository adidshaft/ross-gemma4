# Privacy Architecture

Ross is built around a hard local-first boundary for advocate case work.

Ross does not upload case files, OCR text, prompts, embeddings, filenames, party names, client facts, or extracted legal fields to cloud AI services.

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
- no remote private-matter model APIs
- no analytics SDKs
- no silent case-data upload
- uncertain details remain reviewable

## Public-law Search

This is the only normal user network boundary for legal research.

Rules:

- `Web search` is off by default
- Ross builds the query locally
- Ross shows a preview before anything is sent
- explicit confirmation is required
- only the approved sanitized public-law query may cross the boundary
- case files, document text, filenames, party names, client names, exact private dates, filing references, and factual narratives must not cross the boundary

Sanitizer preservation rules now enforced by tests:

- preserve legal citation patterns such as `Order 39 Rules 1 and 2 CPC`
- preserve statute references such as `Section 138 NI Act`, `Section 482 CrPC`, and `Article 226 Constitution of India`
- do not strip numbers merely because they are numbers
- do strip case-specific identifiers, filenames, contact details, private phrasing, and fake-secret regressions

Current backend guardrails:

- rejects obvious private matter wording such as `my case` and `this matter`
- rejects phone numbers and email addresses
- rejects filing references and filenames
- rejects exact private dates when they are case-specific
- rejects location-like factual phrases
- rejects the fake-secret regression values
- rejects queries that are not general public-law research
- does not expose raw provider internals in normal UI

Manual proof note for April 23, 2026:

- backend smoke used `http://127.0.0.1:8081`
- the approved citation-preserving query returned a safe public-law response
- fake-secret content was rejected at the public-law boundary
- Android emulator boot/install succeeded, but Android app launch remained blocked
- fresh iOS inline review proof remained blocked by simulator tap flakiness

## Gemini boundary

Gemini may only be used server-side for confirmed public-law search.

Rules:

- mobile apps never call Gemini directly
- Gemini receives only the sanitized public-law query
- Gemini must never receive case text, filenames, review fields, party names, client names, or factual matter narratives
- if Gemini is unavailable, Ross falls back to a privacy-safe backend index without echoing the query

## Auth and Session

Auth is separate from matter content.

Rules:

- auth routes must not receive case-file payloads
- refresh and account tokens must not contain case text
- audit logs must not contain raw prompts or raw source text
- Google sign-in failures remain plain-language
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

Acceptable entries include:

- `Checked Private AI availability`
- `Downloaded Private AI Pack`
- `Searched public law`
- `Public-law search unavailable`
- `Generated local export`
- `Document reviewed locally`

The ledger should not expose raw payloads, raw prompts, raw source text, or provider internals.

## Regression guardrail

Fake-secret regression values such as `Raghav Fakepriv`, `9876501234`, `fakepriv@example.com`, `FAKE/123/2026`, and `blue suitcase near temple` may appear in local-only UI, but must not cross the public-law or auth boundary.

## Real-runtime note

This document describes the privacy boundary Ross preserves in the current alpha.

It is not a claim that a real local model has already been proven on hardware.
