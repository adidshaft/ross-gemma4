# Ross Dogfood Proof And Public-Law Polish

## Branch used

Work stayed on:

- `alpha-lawyer-usable-app`

## What changed in this pass

- preserved legal citations in the public-law sanitizer across Rust, iOS, Android, and backend tests
- tightened private-matter stripping for fake secrets and case-specific phrasing
- made the public-law result layout more clearly separate case-file sources from public-law results
- fixed iOS export drafting so ignored review fields do not leak into export content
- added Android export open/share support through a `FileProvider`
- aligned docs with the actual April 23 proof status

## Current proof truth

Freshly proven in this pass:

- Rust, backend, privacy guards, Android build/tests, and iOS build/Swift tests pass
- backend smoke on `http://127.0.0.1:8081` proves citation-preserving public-law search and fake-secret rejection
- iOS demo sign-in, Home, matter creation, Ask Ross add-task, Ask Ross save-next-hearing, matter open, and review-surface reachability were manually re-run
- Android emulator boot and debug APK install were manually re-run

Freshly blocked in this pass:

- iOS inline review actions remain blocked by flaky simulator tap behavior that throws Ross to SpringBoard instead of reliably pressing on-screen review buttons
- Android app launch remains blocked even after successful emulator boot and APK install; `adb` launch returns `Error type 3` while `dumpsys package` still lists `MainActivity`

## Current public-law truth

- legal citations such as `Order 39 Rules 1 and 2 CPC`, `Section 138 NI Act`, `Section 482 CrPC`, and `Article 226 Constitution of India` are preserved in tests
- fake/private matter data such as `Raghav Fakepriv`, `9876501234`, `fakepriv@example.com`, `FAKE/123/2026`, and `blue suitcase near temple` is stripped or blocked
- the exact approved preview query is what backend tests now verify is sent server-side
- mobile apps still never call Gemini directly
- this session observed the privacy-safe backend fixture/index path, not a live Gemini fallback event in product UI

## Screenshot truth

Current tracked bundle:

- `artifacts/qa-screenshots-2026-04-22/`

April 23 captures exist from the simulator pass, but the `artifacts/qa-screenshots-2026-04-23/` bundle was not completed or curated in this session.

## Exact next recommended step

Do one blocker-only follow-up:

1. finish a fresh iOS manual pass that proves review actions, export open, Privacy Ledger, and Settings -> Advanced without the simulator tap regression
2. fix or document the Android emulator launch issue so the installed debug app can actually open
3. rerun the iOS public-law preview -> confirm -> results flow after the citation/layout fixes
4. only then refresh the April 23 screenshot bundle
