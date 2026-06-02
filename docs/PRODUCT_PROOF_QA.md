# Product Proof QA

This document records the current dogfood-readiness proof for Ross on April 23, 2026.

It is intentionally strict about what was actually run, what only passed in automated validation, and what is still blocked.

## Goal

The target dogfood loop for this phase is:

1. launch Ross
2. sign in with demo mode
3. land on Home
4. open or create a matter
5. add a task from the Ask Ross dock
6. save a next hearing/date from the Ask Ross dock
7. import a document
8. review extracted details
9. ask Ross with Public law off
10. turn Public law on and review the sanitized preview
11. confirm search
12. view public-law results separately from case-file sources
13. generate and open a draft export
14. open the Privacy Ledger
15. confirm Settings keeps technical details under `Advanced`

## Fresh manual proof on April 23, 2026

### iOS simulator

Freshly run in this session:

- demo sign-in
- Home load with populated daily sections
- create a new matter
- Ask Ross dock command to add a task
- Ask Ross dock command to save the next hearing
- open the new matter workspace
- reach the real iOS file picker for import
- reopen the seeded `Demo order` document viewer
- confirm the review surface is present with plain-language `Accept`, `Edit`, and `Ignore` controls

Freshly observed iOS blockers:

- the system file picker was reached, but fresh document selection from the picker was not completed in this pass
- inline review taps in the simulator are currently not trustworthy in this environment; repeated taps on visible review buttons misrouted Ross to SpringBoard instead of updating review state
- because of that simulator interaction issue, fresh proof of review `Accept`, `Edit`, `Ignore`, review-to-task/date, export open, Privacy Ledger, and Settings -> Advanced was not completed in this pass
- the current running build still showed a stale `Session expired` banner after simulator relaunches; code was patched to clear that launch-path banner on expired stored sessions, but that patch was not manually re-proven in-app without another restart

Freshly not proven on iOS in this pass:

- review `Accept`
- review `Edit`
- review `Ignore`
- create task/date directly from a review item
- export generation and export opening
- Privacy Ledger opening
- Settings -> Advanced -> Technical diagnostics in the latest pass
- public-law preview -> confirm -> results after the latest citation/layout fixes

### Android emulator

Freshly run in this session:

- boot a local `Pixel_8` AVD
- wait for emulator boot completion
- install the debug APK with `./gradlew :app:installDebug`

Freshly observed Android blocker:

- the emulator boots and the APK installs, but the app does not launch through `adb`
- `adb shell am start -W -n com.ross.android/com.ross.android.MainActivity` returns `Error type 3`
- `adb shell dumpsys package com.ross.android` still shows `MainActivity` registered for `MAIN` and `LAUNCHER`
- because launch is blocked at the emulator level, no fresh Android in-app walkthrough was completed in this pass

Freshly not proven on Android in this pass:

- app launch into Home
- demo sign-in
- dock add-task persistence
- dock save-date persistence
- matter workspace
- document import
- document viewer
- public-law preview -> confirm -> results
- export generation/opening
- Privacy Ledger
- Settings -> Advanced

## Public-law proof and backend smoke

Fresh backend smoke run in this session used:

- `http://127.0.0.1:8081`

Fresh backend smoke results:

- `GET /model-catalog?platform=ios`: passed
- `POST /model-download/session` with a valid pack and device hash: passed
- `POST /public-law/search` with `Order 39 Rules 1 and 2 CPC temporary injunction`: passed
- `POST /public-law/search` with fake-secret content: rejected with a privacy-boundary response

Current backend truth:

- the exact approved query is forwarded server-side for public-law search
- legal citations are preserved in the sanitizer and test suite
- fake/private matter data is still stripped or blocked
- the observed backend source in this smoke run was the privacy-safe fixture/index path, not a live Gemini-grounded response

## Automated validation status

Freshly passing in this repo after the current code changes:

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
  - `./gradlew :app:installDebug`
- iOS:
  - `xcodebuild ... build`
  - `swift test --scratch-path tmp/swiftpm`

Still deferred or limited:

- `xcodebuild test`
  - the shared `Ross` Xcode scheme already has a `TestAction`, but there is still no Xcode-native test target wired into `Testables`
  - `swift test` remains the safe test path for the Swift package coverage in this repo

## Screenshot truth

Current tracked screenshot bundle:

- `artifacts/qa-screenshots-2026-04-22/`

April 23 captures were taken during the fresh iOS simulator pass, but the new bundle was not fully curated or completed in this session.

## Still unproven

Do not claim:

- a fully completed fresh iOS P0 walkthrough for April 23, 2026
- a fresh Android in-app walkthrough for April 23, 2026
- review `Accept`, `Edit`, and `Ignore` as manually proven in this pass
- review-to-task/date as manually proven in this pass
- export open or Privacy Ledger open as manually proven in this pass
- Settings -> Advanced as manually proven in this pass
- real Google OAuth with working credentials
- backend-backed Apple sign-in
- physical quick unlock proof
- physical iPhone install/provisioning
- physical iPhone downloaded-model proof over user-imported files
- live Gemini fallback observation in product UI

Already proven after this April screenshot bundle:

- iOS simulator real GGUF smoke passed on 2026-06-02 with `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime`.
- That simulator smoke covered English, Bengali, Hindi, and general-answer paths, but it does not replace a physical-device download/imported-file QA pass.
- A stricter native-marker simulator rerun later on 2026-06-02 passed with `source_native_model=true`, `bengali_native_model=false`, `hindi_native_model=true`, and `general_native_model=true`.
- Do not claim native Bengali model output until a later pass/fail line includes `bengali_native_model=true`; the current Bengali product answer is safe because Ross used source-preserving fallback.

## Exact next recommended step

Use the current branch and stay narrow:

1. finish one clean iOS simulator pass on a fresh launch path that proves review `Accept`, `Edit`, `Ignore`, export open, Privacy Ledger, and Settings -> Advanced without the SpringBoard tap regression
2. resolve the Android emulator launch blocker so the debug build can actually open from `adb`
3. rerun the public-law preview -> confirm -> results flow on iOS after the citation/layout fixes
4. curate the April 23 screenshot bundle only after those proofs are complete
