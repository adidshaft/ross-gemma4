# Ross Internal Dogfood Readiness Report

## Branch used

Work stayed on the existing active branch:

- `alpha-lawyer-usable-app`

No new branch was created on top of active feature work.

## Repo-state handling

Included in this phase:

- iOS daily-usage workflow refinements
- Android daily-usage workflow refinements
- demo workspace seeding and reset behavior
- task and matter dashboard logic
- public-law preview hardening and backend smoke coverage
- docs and runbooks
- screenshot refresh

Left intentionally untouched:

- `SCRIPT.md`
- local Xcode workspace state
- logo and design artifact folders
- research notes
- `shared/assets/`
- `backend/.env.local`

No secrets, provisioning profiles, certificates, or local environment files were committed.

## Current proof summary

Freshly observed on iOS in this session:

- demo sign-in
- populated Home
- create matter
- Ask Ross add task
- Ask Ross save next hearing
- document import
- document viewer open
- local Ask Ross with `Web Search` off
- preview before public-law search
- successful public-law result for a generic law question
- visible split between case-file context and public-law results

Freshly observed on Android in this session:

- debug install
- app launch
- demo sign-in
- populated Home
- demo matter open
- `Web Search` can be toggled on with plain privacy copy

Current Android blocker:

- matter-scoped free-text dock input is not yet proven to persist task/date actions cleanly

## Explicitly still unproven

This phase still does not prove:

- export generation and export opening in the latest iOS pass
- Privacy Ledger opening in the latest iOS pass
- Settings -> Advanced in the latest iOS pass
- Android dock action persistence
- Android document flow
- Android public-law preview -> confirm -> results
- real Google OAuth with real credentials
- backend-backed Apple sign-in
- physical iPhone install or provisioning completion
- quick unlock on real hardware
- real local model proof on device

## Public-law truth

The current public-law path remains:

1. local handling first
2. preview in the app
3. explicit confirmation
4. Ross backend call
5. server-side Gemini only if configured there
6. privacy-safe fallback if the live connector is unavailable

Manual proof URL used on iOS in this session:

- `http://127.0.0.1:8787`

Android emulator default:

- `http://10.0.2.2:8080`

## Screenshot treatment

Current screenshots are curated under:

- `artifacts/qa-screenshots-2026-04-22/`

Older tracked screenshot bundles under `artifacts/ios/light/` and `artifacts/ios/dark/` are now legacy and should not be treated as current product truth.

## Exact next recommended step

Run a short blocker-only pass:

1. iOS export generation -> open export -> open Privacy Ledger -> open Settings -> Advanced
2. Android dock `add task` and `save next hearing` persistence
3. Android public-law preview -> confirm -> results
4. iOS sanitizer polish for legal citations such as `Order 39 Rules 1 and 2 CPC`
