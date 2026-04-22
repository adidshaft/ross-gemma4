# Internal Alpha Readiness

This document is the truth-in-status sheet for Ross on April 23, 2026.

It is intentionally precise about what is working, what is partially proven, and what is still blocked.

## Platform summary

### iOS

Build and tests:

- `xcodebuild ... build`: passing
- `swift test --scratch-path tmp/swiftpm`: passing

Fresh manual proof on April 23:

- demo sign-in to Home
- populated Home dashboard
- create matter
- Ask Ross add-task command
- Ask Ross save-next-hearing command
- open the new matter workspace
- reach the real file picker for import
- reopen the seeded document viewer and review surface
- confirm plain-language review controls are visible

Current truth:

- the iOS product shell is close to dogfood quality
- the review surface is present and plain-language
- fresh inline review action proof is blocked by simulator interaction flakiness, not by missing UI

Still needing a fresh iOS proof pass:

- review `Accept`
- review `Edit`
- review `Ignore`
- create task/date directly from review
- export generation and export opening
- Privacy Ledger opening
- Settings -> Advanced
- fresh public-law preview -> confirm -> results after the latest sanitizer/layout changes

### Android

Build and tests:

- `./gradlew :app:testDebugUnitTest`: passing
- `./gradlew :app:assembleDebug`: passing
- `./gradlew :app:installDebug`: passing

Fresh manual environment proof on April 23:

- local `Pixel_8` emulator booted
- debug APK installed on the emulator

Current blocker:

- the app does not launch through `adb` even though the installed package lists `MainActivity` as the launcher activity
- because launch is blocked, the fresh Android in-app product walkthrough was not completed

### Backend

Validated:

- tests pass
- typecheck passes
- build passes
- public-law smoke path works on `http://127.0.0.1:8081`

Current truth:

- public-law route is live
- only the approved sanitized query is forwarded
- Gemini remains server-side only
- the fixture/index fallback path was observed in smoke coverage

### Rust

Validated:

- `cargo test`: passing

Current truth:

- shared sanitizer logic now preserves legal citations while stripping private matter details

### Privacy guards

Validated:

- boundary verification script passes
- no-cloud-llm script passes
- no-analytics script passes
- no-large-model-assets script passes
- onboarding copy boundary script passes

## Feature readiness matrix

### Launch and auth

- demo sign-in: manually proven on iOS in this pass
- Google OAuth wiring: present, not manually proven with real credentials
- Apple sign-in: local-only on iOS, not backend-backed
- quick unlock: implemented, not physically proven
- stale launch `Session expired` banner on iOS: code patched to suppress it on expired stored-session fallback, not yet manually re-proven without another app restart

### Home and daily dashboard

- Home dashboard: manually proven on iOS in this pass
- attention, dates, tasks, and review counts: visible on iOS in this pass

### Matters

- matter list and workspace: manually proven earlier in the phase and partially re-entered in this pass
- create matter: manually proven on iOS in this pass
- Android matter proof: blocked at app launch

### Tasks and dates

- iOS Ask Ross add-task: manually proven in this pass
- iOS Ask Ross save-next-hearing: manually proven in this pass
- Android dock persistence: not freshly proven in this pass because the app did not launch

### Documents and review

- file picker reachability on iOS: proven
- fresh file import completion in this pass: not proven
- review surface visibility on iOS: proven
- review action state changes on iOS: not proven due simulator tap blocker

### Ask Ross and public-law

- Web-off local behavior: previously proven in this phase, not freshly re-run after the latest fixes in this pass
- citation-preserving sanitizer: proven by tests
- public-law visual separation: implemented in code for iOS and Android, not freshly re-walked end-to-end in this pass

### Notes, exports, ledger, settings

- iOS export drafting behavior: fixed in code for ignored review fields
- fresh export open proof: not completed
- fresh Privacy Ledger open proof: not completed
- fresh Settings -> Advanced proof: not completed

## Screenshot truth

Current tracked screenshot bundle:

- `artifacts/qa-screenshots-2026-04-22/`

April 23 captures were taken during live iOS work, but the new bundle was not completed or curated in this session.

## Still unproven

Do not claim:

- a full fresh iOS P0 flow completion for April 23
- any fresh Android in-app walkthrough for April 23
- real Google OAuth success
- backend-backed Apple auth
- quick unlock on hardware
- physical iPhone install completion
- real local model proof on device
- live Gemini fallback behavior in the app UI
