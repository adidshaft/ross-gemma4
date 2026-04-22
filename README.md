# Ross

Ross is a privacy-first legal workbench for Indian advocates.

The current phase is `Ross Internal Dogfood Readiness`: prove and polish the existing app so a founder or a small set of trusted lawyers can use it without an engineer narrating the flow.

## Current daily loop

The target lawyer-facing flow is:

1. Language selection
2. Sign in
3. Optional quick unlock
4. Home

The current morning workflow is:

1. Open Ross
2. See what needs attention today
3. Open or create a matter
4. Add or import a file
5. Review extracted details locally
6. Ask Ross from local files with `Web search off`
7. Optionally turn `Web search` on and confirm a sanitized public-law query
8. Generate a draft note or chronology
9. Open the Privacy Ledger if needed

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

As of April 22, 2026, recent validation in this repo includes:

- Rust tests pass
- backend tests, typecheck, and build pass
- privacy guard scripts pass
- Android unit tests pass
- Android debug assemble passes
- iOS simulator build passes
- iOS Swift tests pass

Recent manual iOS simulator proof includes:

- sign-in shell renders
- demo sign-in lands on Home
- Home shows real local dashboard state
- create matter
- Ask Ross add-task action
- Ask Ross save-next-hearing action
- document import into a matter
- matter list opens
- matter workspace opens
- file room opens
- document viewer and review screen open
- Ask Ross works with Web off
- public-law preview appears before search
- public-law results render for a generic law question

Recent manual Android emulator proof includes:

- debug app install
- app launch
- demo sign-in
- populated Home
- demo matter opens
- Web Search can be toggled on from the Ask Ross tools sheet

Current Android blocker from live QA:

- matter-scoped free-text `add task ...` produced `Tasks from your files` suggestions instead of a clearly persisted task in the `Tasks` tab

Fresh Android proof of dock action persistence, document flow, exports, ledger, and Settings is still pending.

## What is not proven yet

Do not claim these unless separately run and recorded:

- real Google OAuth with real credentials
- backend-backed Apple sign-in
- physical iPhone install and provisioning completion
- quick unlock on real hardware
- real local model proof on device
- production public-law provider readiness

Apple sign-in is currently iOS-only and local-session only.

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
- only the sanitized public-law query crosses the network boundary

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
- the default port is `8080` if free

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
- physical iPhone should use your Mac's LAN IP
- an in-app backend override is available under `Settings > Advanced`

## Android

CLI build:

```bash
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

Android backend notes:

- the default emulator mapping is `http://10.0.2.2:8080`
- if your backend runs on `8787`, use `http://10.0.2.2:8787`
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

The current curated simulator screenshots live in:

- `artifacts/qa-screenshots-2026-04-22/`

See [`docs/INTERNAL_ALPHA_READINESS.md`](/Users/amanpandey/projects/ross/docs/INTERNAL_ALPHA_READINESS.md) for which screens were freshly captured in this phase.
