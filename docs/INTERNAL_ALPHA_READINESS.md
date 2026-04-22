# Internal Alpha Readiness

This document is the truth-in-status sheet for Ross on April 22, 2026.

It is intentionally precise about what is working, what is partially proven, and what is still unproven.

## Platform summary

### iOS

Build and tests:

- `xcodebuild ... build`: passing
- `swift test --scratch-path tmp/swiftpm`: passing

Fresh manual proof:

- sign-in shell
- demo sign-in to Home
- Home dashboard
- matter list
- matter workspace
- file room
- document viewer and review surface
- Ask Ross with Web off
- public-law preview
- Privacy Ledger
- notes and exports surface
- Settings surface

Still needing a fresh proof pass:

- create matter on the refreshed build
- task and date creation on the refreshed build
- export open after generation
- final public-law results screen after the latest code changes

### Android

Build and tests:

- `./gradlew :app:testDebugUnitTest`: passing
- `./gradlew :app:assembleDebug`: recently passing in this phase

Fresh manual proof:

- none in this session

Current truth:

- workflow is implemented and tested in code
- no emulator was attached for a fresh walkthrough

### Backend

Validated:

- tests pass
- typecheck passes
- build passes
- public-law smoke path works

Current truth:

- public-law route is live
- Gemini is server-side only
- fallback path exists and is tested

### Rust

Validated:

- `cargo test`: passing

### Privacy guards

Validated:

- boundary verification script passes
- no-cloud-llm script passes
- no-analytics script passes
- no-large-model-assets script passes
- onboarding copy boundary script passes

## Feature readiness matrix

### Launch and auth

- language selection: present on iOS and in alpha flow docs; not freshly re-proven end-to-end in this exact final pass
- demo sign-in: manually proven on iOS
- Google OAuth wiring: present, not manually proven with real credentials
- Apple sign-in: local-only on iOS, not backend-backed
- quick unlock: implemented, not physically proven

### Home and daily dashboard

- Home dashboard: manually proven on iOS
- today summary and attention counts: manually visible on iOS
- upcoming dates: manually visible on iOS
- open tasks: manually visible on iOS
- review items: manually visible on iOS
- recent activity: manually visible on iOS

### Matters

- matter list: manually proven on iOS
- matter workspace: manually proven on iOS
- create matter: manually proven earlier in this phase, but not re-proven after the latest code changes
- edit and archive matter: present in code, not freshly re-proven manually in the final sweep

### Tasks and dates

- task and date surfaces: manually visible on iOS
- no-silent-task-inflation bug: fixed in code and covered by tests
- add and update task/date flows: partially proven by UI visibility, still needs a clean re-run after relaunch

### Documents and review

- file room: manually proven on iOS
- document import action: visible and reachable on iOS
- fresh import of a new local file: not freshly proven in the final sweep
- document viewer: manually proven on iOS
- review controls: manually visible on iOS
- accept, edit, ignore review actions: visible; still needs a clean fresh action pass after relaunch

### Ask Ross

- local Ask Ross with Web off: manually proven on iOS
- sanitized preview before public-law search: manually proven on iOS
- public-law results from the refreshed build after latest changes: not freshly re-proven

### Notes and exports

- notes and exports surface: manually proven on iOS
- generate controls visible: manually proven on iOS
- open generated draft: not freshly proven in the final sweep

### Privacy Ledger

- ledger opens: manually proven on iOS
- plain-language entries: manually proven on iOS

### Settings

- lawyer-facing settings: manually proven on iOS
- Advanced separation: manually proven on iOS
- Technical diagnostics inside Advanced only: present in product structure; expanded panel was not freshly captured in this final sweep

## Screenshot bundle

Current screenshot bundle:

- `artifacts/qa-screenshots-2026-04-22/`

Fresh current-shell captures in this phase include:

- language / welcome
- sign-in
- demo Home
- matter list
- matter workspace
- file room
- document review
- Ask Ross with Web off
- public-law preview
- Privacy Ledger
- notes and exports
- Settings

Legacy tracked bundles under `artifacts/ios/light/` and `artifacts/ios/dark/` should not be treated as current product truth.

## Still unproven

Do not claim:

- real Google OAuth success
- backend-backed Apple auth
- quick unlock on hardware
- physical iPhone install completion
- fresh Android emulator walkthrough
- real local model proof on device
