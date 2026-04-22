# Ross

Ross is a privacy-first legal workbench for Indian advocates.

The current phase is `Ross Dogfood Proof & Public-Law Polish`: prove and polish the existing app so a founder or a small set of trusted lawyers can use it without an engineer narrating the flow.

## Current daily loop

The target lawyer-facing flow is:

1. open Ross
2. sign in
3. land on Home
4. open or create a matter
5. add or import a file
6. review extracted details locally
7. ask Ross from local files with `Web search off`
8. optionally turn `Web search` on and confirm a sanitized public-law query
9. generate a draft note or chronology
10. open the Privacy Ledger if needed

Normal UI stays lawyer-friendly:

- `Draft for advocate review`
- `Source-backed`
- `Case files stay on this device`
- `Public-law search sends only a sanitized query`
- `Needs review`
- `Verified from source`
- `Private AI on this device`
- `Web search is off`
- `Review before searching public law`

Technical details stay under `Settings > Advanced > Technical diagnostics`.

## What is currently proven

As of April 23, 2026, fresh validation in this repo includes:

- Rust tests pass
- backend tests, typecheck, and build pass
- privacy guard scripts pass
- Android unit tests pass
- Android debug assemble and install pass
- iOS simulator build passes
- iOS Swift tests pass

Fresh backend smoke in this session used `http://127.0.0.1:8081` and proved:

- `GET /model-catalog?platform=ios`
- `POST /model-download/session`
- `POST /public-law/search` for `Order 39 Rules 1 and 2 CPC temporary injunction`
- fake-secret public-law rejection for private content

Fresh manual iOS simulator proof in this session includes:

- demo sign-in
- Home load
- create matter
- Ask Ross add-task command
- Ask Ross save-next-hearing command
- new matter workspace open
- file picker reachability for import
- seeded document viewer/review surface reopen
- visible plain-language `Accept`, `Edit`, and `Ignore` review controls

Fresh Android environment proof in this session includes:

- local emulator boot
- debug APK install

## What is not proven yet

Do not claim these unless separately run and recorded:

- a fully completed fresh iOS P0 walkthrough for April 23, 2026
- fresh iOS proof of review action state changes
- fresh iOS proof of export open, Privacy Ledger open, and Settings -> Advanced
- fresh Android in-app walkthrough
- real Google OAuth with real credentials
- backend-backed Apple sign-in
- physical iPhone install and provisioning completion
- quick unlock on real hardware
- real local model proof on device
- live Gemini fallback behavior in the app UI

Apple sign-in is currently iOS-only and local-session only.

## Current blockers

iOS:

- fresh inline review taps are blocked by flaky simulator interaction that throws Ross to SpringBoard instead of reliably pressing on-screen review buttons

Android:

- the emulator boots and the APK installs, but `adb` launch still fails with `Error type 3` even though `dumpsys package com.ross.android` shows `MainActivity` registered

## Demo mode

`Open demo mode` is the supported local QA path.

Demo mode now seeds a clearly synthetic workspace with:

- `Demo Matter: Sharma v. Rana`
- upcoming dates
- open tasks
- review items
- demo documents

This data is local only and resettable from `Settings > Account > Reset demo data`.

## Public-law search boundary

Public-law search is optional and separate from private matter work.

- `Web search` is off by default
- the app builds a generic public-law query locally
- the user sees the preview before anything is sent
- confirmation is required
- only the approved sanitized public-law query crosses the network boundary

Legal citations now preserved by tests include:

- `Order 39 Rules 1 and 2 CPC`
- `Section 138 NI Act`
- `Section 482 CrPC`
- `Article 226 Constitution of India`

The mobile apps never call Gemini directly.

If the backend is configured with `ROSS_PUBLIC_LAW_GEMINI_API_KEY` or `GEMINI_API_KEY`, the Ross backend may use Gemini with Google Search grounding for confirmed public-law search. If that connector is unavailable, Ross falls back to a privacy-safe backend index for QA.

Case files, document text, filenames, party names, client details, review fields, and private factual narratives stay local.

## Backend setup

Install once:

```bash
cd /Users/amanpandey/projects/ross/backend
npm install
```

Start the backend:

```bash
cd /Users/amanpandey/projects/ross/backend
npm run dev
```

Notes:

- the backend auto-loads `backend/.env` and `backend/.env.local`
- `backend/.env.local` is gitignored and is the right place for your local Gemini key
- `GET /health` is available for smoke checks
- this session used port `8081` because `8080` was already occupied locally

## iOS

Open [`ios/Ross.xcodeproj`](/Users/amanpandey/projects/ross/ios/Ross.xcodeproj) in Xcode and run the shared `Ross` scheme.

CLI build:

```bash
cd /Users/amanpandey/projects/ross/ios
xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' -derivedDataPath tmp/DerivedData build
swift test --scratch-path tmp/swiftpm
```

iOS backend notes:

- iOS Simulator can use `http://127.0.0.1:<port>`
- this session's backend smoke used `http://127.0.0.1:8081`
- physical iPhone should use your Mac's LAN IP
- an in-app backend override is available under `Settings > Advanced`

## Android

CLI build:

```bash
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
./gradlew :app:installDebug
```

Android backend notes:

- the default emulator mapping is `http://10.0.2.2:8080`
- if your backend runs on `8081`, use `http://10.0.2.2:8081`
- physical devices should use your Mac's LAN IP
- the app also supports an in-app backend override under `Settings > Advanced`

## Privacy guards

```bash
cd /Users/amanpandey/projects/ross
./scripts/dev/verify-boundaries.sh
./scripts/ci/check-no-cloud-llm.sh
./scripts/ci/check-no-analytics.sh
./scripts/ci/check-no-large-model-assets.sh
./scripts/ci/check-onboarding-copy-boundary.sh
```

## QA and runbooks

- [`docs/PRODUCT_PROOF_QA.md`](/Users/amanpandey/projects/ross/docs/PRODUCT_PROOF_QA.md)
- [`docs/REAL_WORLD_USAGE_QA.md`](/Users/amanpandey/projects/ross/docs/REAL_WORLD_USAGE_QA.md)
- [`docs/INTERNAL_ALPHA_QA.md`](/Users/amanpandey/projects/ross/docs/INTERNAL_ALPHA_QA.md)
- [`docs/PUBLIC_LAW_QA.md`](/Users/amanpandey/projects/ross/docs/PUBLIC_LAW_QA.md)
- [`docs/PUBLIC_LAW_SANITIZATION_RULES.md`](/Users/amanpandey/projects/ross/docs/PUBLIC_LAW_SANITIZATION_RULES.md)
- [`docs/AUTH_QA.md`](/Users/amanpandey/projects/ross/docs/AUTH_QA.md)
- [`docs/DEVICE_INSTALL_QA.md`](/Users/amanpandey/projects/ross/docs/DEVICE_INSTALL_QA.md)
- [`docs/MANUAL_CASE_ASSOCIATE_E2E.md`](/Users/amanpandey/projects/ross/docs/MANUAL_CASE_ASSOCIATE_E2E.md)
- [`docs/INTERNAL_ALPHA_READINESS.md`](/Users/amanpandey/projects/ross/docs/INTERNAL_ALPHA_READINESS.md)
- [`docs/PRIVACY_ARCHITECTURE.md`](/Users/amanpandey/projects/ross/docs/PRIVACY_ARCHITECTURE.md)
- [`docs/OFFLINE_BEHAVIOR.md`](/Users/amanpandey/projects/ross/docs/OFFLINE_BEHAVIOR.md)
- [`docs/PRIVATE_ASSISTANT_USAGE.md`](/Users/amanpandey/projects/ross/docs/PRIVATE_ASSISTANT_USAGE.md)
- [`docs/PUBLIC_LAW_LOCAL_QUERY_FLOW.md`](/Users/amanpandey/projects/ross/docs/PUBLIC_LAW_LOCAL_QUERY_FLOW.md)
- [`docs/NEXT_STEP_REPORT.md`](/Users/amanpandey/projects/ross/docs/NEXT_STEP_REPORT.md)

## Screenshot bundle

Current tracked screenshots still live in:

- `artifacts/qa-screenshots-2026-04-22/`

The April 23 bundle was not fully curated in this session and should not yet be treated as product truth.
