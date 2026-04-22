# Ross Real-World Usage Alpha Report

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

## What changed in product terms

Ross now leans much harder into the real daily loop:

- demo sign-in lands on a populated synthetic workspace instead of an abstract shell
- Home answers `What needs my attention today?`
- matters carry dates, tasks, documents, review work, notes, and exports in one place
- public-law search remains preview-gated and sanitized
- Privacy Ledger stays lawyer-readable

## Fresh proof from this phase

Freshly observed in the iOS simulator on April 22, 2026:

- demo sign-in lands on Home
- Home shows live local dashboard sections
- matter list opens
- matter workspace opens
- file room opens
- document viewer opens
- review actions are visible
- Ask Ross works with Web off
- public-law preview appears before search
- Privacy Ledger opens
- notes and exports surface opens
- Settings remain plain-language with Advanced separated

Freshly proven by code and tests in this phase:

- demo workspace seeding is intentional and resettable
- generic morning questions produce a research-safe public-law preview
- marking matter dates done no longer silently inflates open tasks
- Android and iOS both carry the same no-silent-task-inflation regression

## Explicitly still unproven

This phase does not prove:

- real Google OAuth with real credentials
- backend-backed Apple sign-in
- physical iPhone install or provisioning completion
- quick unlock on real hardware
- Android emulator walkthrough in this session
- real local model proof on device

## Public-law truth

The current public-law path is:

1. local preview in the app
2. explicit confirmation
3. Ross backend call
4. Gemini with Google Search grounding only if configured server-side
5. privacy-safe fallback index if the live connector fails or is unavailable

The backend route rejects obvious private matter content, identifiers, filenames, exact dates, and the fake-secret regression values before any Gemini request is made.

Backend logging records hashed metadata, not the raw public-law query in production-style paths.

## Screenshot treatment

Current screenshots are curated under:

- `artifacts/qa-screenshots-2026-04-22/`

Older tracked screenshot bundles under `artifacts/ios/light/` and `artifacts/ios/dark/` are now legacy and should not be treated as current product truth.

## Exact next recommended step

Run one clean, fresh iOS simulator pass after relaunching the newly built app and record:

1. create matter
2. add task and date
3. import a new file
4. accept, edit, and ignore a review item
5. generate and open one export draft
6. confirm public-law search results end-to-end on the refreshed build

After that, the next proof track should be a separate credential and hardware pass:

- real Google OAuth
- physical-device quick unlock
- physical iPhone install
- real local model proof
