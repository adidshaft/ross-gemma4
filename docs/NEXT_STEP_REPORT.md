# Ross Internal Alpha Stabilization Report

## Branch choice

The requested branch name for this phase was `alpha-internal-stabilization`.

This repo was already on active feature branch `alpha-lawyer-usable-app` with ongoing transitional work, so the work stayed on that branch instead of creating a new branch on top of active changes.

## Repo-state treatment

Inspected and intentionally handled in one of three ways:

- included in this phase: Android auth and shell work, backend auth and runtime connectivity work, docs and QA runbooks, targeted iOS auth-shell fixes
- left untouched as unrelated or not yet ready: `SCRIPT.md`, `artifacts/`, local Xcode workspace state, research notes, design folders, and other user-owned untracked files
- documented rather than cleaned: screenshot artifacts and local QA byproducts

No large model files, secrets, provisioning profiles, or generated screenshot bundles were intentionally committed from this report alone.

## Phase outcome

This phase is moving Ross from a transitional repo toward a manually testable internal alpha with:

- stable auth-shell direction
- demo sign-in support
- Home-first workflow emphasis
- app-to-backend public-law connectivity work
- plain-language settings and privacy copy
- stronger QA documentation

## Verified in-session

Verified during this phase:

- Rust tests passed
- backend tests, typecheck, and build passed
- privacy guard scripts passed
- Android unit tests and debug assemble passed
- iOS simulator build and Swift tests passed
- backend smoke reached `GET /health`
- backend smoke reached `POST /public-law/search`
- iOS simulator demo sign-in was manually observed landing on Home

## Explicitly not proven by this report

This report does not claim:

- real Google OAuth success with real credentials
- backend-backed Apple sign-in
- physical iPhone installation completion
- real local model proof
- production public-law provider integration

## Current backend truth

The current public-law path is live from the Ross backend for local QA. The backend can now call Gemini with Google Search grounding, but only after Ross sends a sanitized public-law query through the explicit preview-confirmation flow.

This repo snapshot does not include a configured Gemini key, so live Gemini grounding is not proven in this report. Without that key, the backend falls back to privacy-safe fixture results for QA.

## Current UI truth

Normal UI should remain lawyer-facing:

- Home
- Cases
- Ask Ross
- Settings

Diagnostics stay behind `Settings > Advanced > Technical diagnostics`.

## Treatment of SCRIPT.md and artifacts

- `SCRIPT.md` remains intentionally untracked and untouched in this phase unless separately curated
- `artifacts/` remains intentionally untouched except for manual QA outputs and screenshot storage

## Exact next recommended step

Complete one clean manual app pass on a fresh build and record it in [`docs/INTERNAL_ALPHA_QA.md`](/Users/amanpandey/projects/ross/docs/INTERNAL_ALPHA_QA.md):

1. demo sign-in
2. create matter
3. import document
4. review one field
5. Ask Ross with Web off
6. public-law preview and confirmed search with Web on
7. export
8. Privacy Ledger
9. Settings and Advanced

After that, the next proof track should be a separate, explicit run for:

- real Google OAuth with real credentials
- physical-device quick unlock
- physical iPhone install
- real local model proof
