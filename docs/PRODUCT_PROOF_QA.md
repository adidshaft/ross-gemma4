# Product Proof QA

This document records the current dogfood-readiness proof for Ross on April 22, 2026.

It is intentionally strict about what was actually run, what only passed in automated validation, and what still needs a fresh manual pass.

## Goal

The target dogfood loop is:

1. launch Ross
2. sign in with demo mode
3. land on Home
4. open or create a matter
5. add a task from the Ask Ross dock
6. save a next hearing/date from the Ask Ross dock
7. import a document
8. review extracted details
9. ask Ross with `Web Search` off
10. turn `Web Search` on and review the sanitized preview
11. confirm search
12. view public-law results separately from case-file sources
13. generate and open a draft export
14. open the Privacy Ledger
15. confirm Settings keeps technical details under `Advanced`

## Fresh manual proof

### iOS simulator

Freshly run in this session after commit `76c387e`:

- demo sign-in
- Home load with live sections for attention, dates, tasks, review work, active matters, and Ask Ross
- plain-language private assistant copy on the main flow
- create matter for `Walkthrough Matter: Rao v. Singh`
- Ask Ross local command to add a task
- Ask Ross local command to save the next hearing
- document import into the new matter
- document viewer open
- local Ask Ross answer with `Web Search` off
- `Web Search` on showing a preview before the backend call
- successful public-law result on a generic law question
- visible separation between case-file content and public-law results

Freshly observed issues on iOS:

- the public-law sanitizer is over-aggressive for legal citations and stripped `39` from `Order 39 Rules 1 and 2 CPC`
- the public-law answer layout still feels mixed because local review content and public-law content appear too close together
- the private assistant status still needs one clean confirmation pass from Home after the latest local UI changes

Not freshly proven in this iOS pass:

- review `Edit`
- review `Ignore`
- create task/date directly from a review item
- export generation and export opening
- Privacy Ledger opening in the latest pass
- Settings -> Advanced -> Technical diagnostics in the latest pass

### Android emulator

Freshly run in this session:

- install debug APK
- launch app
- open demo mode
- land on Home with populated synthetic data
- open `Demo Matter: Sharma v. Rana`
- open the Ask Ross tools sheet
- toggle `Web Search` from off to on with the expected plain-language privacy copy

Freshly observed Android blocker:

- matter-scoped Ask Ross free-text input did not prove the intended persisted-action path
- entering `add task review latest order` produced a `Tasks from your files` answer with suggested tasks, but the `Tasks` tab did not clearly show a newly persisted task
- because of that inconsistency, Android dock command persistence is not proven yet

Android flow still not proven in this session:

- create matter
- saved next hearing/date from the dock
- document import
- document viewer
- public-law preview -> confirm -> results end to end
- export generation/opening
- Privacy Ledger opening
- Settings -> Advanced audit

## Backend URLs used

iOS simulator manual public-law proof used:

- `http://127.0.0.1:8787`

Android emulator default path currently documented in the app:

- `http://10.0.2.2:8080`

Physical device pattern:

- `http://<your-mac-lan-ip>:<port>`

## Automated validation status

Recently passing in this repo:

- Rust: `cargo test`
- backend: `npm test`
- backend: `npm run typecheck`
- backend: `npm run build`
- privacy guards:
  - `./scripts/dev/verify-boundaries.sh`
  - `./scripts/ci/check-no-cloud-llm.sh`
  - `./scripts/ci/check-no-analytics.sh`
  - `./scripts/ci/check-no-large-model-assets.sh`
  - `./scripts/ci/check-onboarding-copy-boundary.sh`
- Android:
  - `./gradlew :app:testDebugUnitTest`
  - `./gradlew :app:assembleDebug`
- iOS:
  - `xcodebuild ... build`
  - `swift test --scratch-path tmp/swiftpm`
  - `swift run --scratch-path tmp/swiftpm Ross --generate-screenshots`

## Still unproven

Do not claim:

- real downloaded on-device model proof
- real Google OAuth with working credentials
- backend-backed Apple sign-in
- physical quick unlock proof
- physical iPhone install/provisioning
- `xcodebuild test`

## Exact next recommended step

Run one clean follow-up proof pass with the current build and focus only on the remaining blockers:

1. iOS export generation -> open export -> open Privacy Ledger -> open Settings -> Advanced
2. Android dock command persistence for task/date actions
3. Android public-law preview -> confirm -> results
4. iOS public-law citation sanitization polish
