# Public-Law QA

This runbook covers Ross public-law search, backend configuration, privacy guardrails, and fallback behavior.

## Product rules

Public-law search is optional and separate from private case work.

Required user flow:

1. `Web search` is off by default
2. user turns it on explicitly
3. Ross builds the public-law query locally
4. Ross shows the sanitized preview
5. user confirms
6. Ross backend performs the search

The mobile apps must never call Gemini directly.

## Backend configuration

Recommended local backend file:

- `backend/.env.local`

Relevant values:

- `PORT=8787`
- `ROSS_PUBLIC_BASE_URL=http://127.0.0.1:8787`
- `ROSS_PUBLIC_LAW_GEMINI_API_KEY=...`

The backend also accepts:

- `GEMINI_API_KEY`

Start command:

```bash
cd /Users/amanpandey/projects/ross/backend
npm run dev
```

## Client backend URLs

iOS Simulator:

- `http://127.0.0.1:8787`

Android emulator:

- `http://10.0.2.2:8787`

Physical device:

- `http://<your-mac-lan-ip>:8787`

Ross also supports `Settings > Advanced > Save test server`.

## What the backend accepts

The `/public-law/search` route requires:

- `query`
- `jurisdiction`
- `language`
- `confirmedPublicPreview: true`

The route rejects requests before search if the query looks private or not truly public-law research.

## Implemented guardrails

The backend rejects queries containing:

- private matter wording like `my case` or `this matter`
- phone numbers
- email addresses
- filing references
- filenames
- exact private dates
- location-style factual details
- fake-secret regression values
- non-public-law or non-research phrasing

The backend also rejects unexpected case-data payload keys before parsing the route body.

## Allowed query shape

The safe shape is general public-law research, for example:

- `Indian public law guidance on court procedure and hearing dates`
- `Indian public law guidance on filing compliance and limitation`
- `Indian public law guidance on court orders and order directions`
- `Indian public law guidance on affidavit practice and evidence procedure`

## Disallowed query shape

These should be rejected:

- case-specific party names
- client details
- document filenames
- copied factual narratives
- exact filing references
- pasted order text
- private addresses, phone numbers, or email addresses

## Gemini behavior

If the backend has a Gemini key:

- Gemini is used server-side only
- Google Search grounding is requested
- only the sanitized query is sent

If Gemini fails or has no usable grounding:

- Ross falls back to the privacy-safe backend index
- the user flow remains intact
- the raw query is not echoed back

## Logging behavior

Public-law logging should record:

- route
- query hash
- query length
- reason counts when rejected

Public-law logging should not record:

- raw public-law query in production-style paths
- private matter text
- filenames
- fake-secret regression values

## Smoke checks

Health:

```bash
curl http://127.0.0.1:8787/health
```

Public-law search:

```bash
curl -X POST http://127.0.0.1:8787/public-law/search \
  -H 'content-type: application/json' \
  -d '{"query":"Indian public law guidance on court procedure and hearing dates","jurisdiction":"IN-ALL","language":"en","confirmedPublicPreview":true}'
```

Rejection check:

```bash
curl -X POST http://127.0.0.1:8787/public-law/search \
  -H 'content-type: application/json' \
  -d '{"query":"Need public-law guidance for Raghav Fakepriv in FAKE/123/2026","jurisdiction":"IN-ALL","language":"en","confirmedPublicPreview":true}'
```

Expected rejection:

- `400`
- no echoed fake secret in the response body

## Current truth on April 22, 2026

Freshly proven in this phase:

- preview appears before search on iOS simulator
- backend smoke works
- connector fallback path works
- backend tests prove Gemini only receives the sanitized query

Not freshly proven in this phase:

- a brand-new in-app public-law results screen on the refreshed build after the latest code changes
