# Ross

Ross is a privacy-first legal workbench for Indian advocates.

The current goal is a clean internal alpha that can be installed, opened, signed into, used through the core legal workflow, and manually QA'd without guessing.

## Internal alpha shape

The current lawyer-facing flow is:

1. Language selection
2. Sign in
3. Optional quick unlock
4. Home

The main daily workflow is:

1. Home
2. Open or create a matter
3. Import a document
4. Review details
5. Ask Ross from local files
6. Optionally run a sanitized public-law search
7. Export a draft
8. Open the Privacy Ledger

Normal UI language stays lawyer-friendly:

- `Draft for advocate review`
- `Source-backed`
- `Case files stay on this device`
- `Public-law search sends only a sanitized query`
- `Needs review`
- `Verified from source`
- `Private AI on this device`

Technical diagnostics stay under `Settings > Advanced > Technical diagnostics`.

## What is verified in this phase

As of April 22, 2026, this repo has recent passing validation for:

- Rust tests
- backend tests, typecheck, and build
- privacy guard scripts
- Android unit tests and debug assemble
- iOS simulator build and Swift tests

Demo sign-in is the supported local QA path.

Google sign-in wiring is present, but real Google OAuth must not be treated as proven unless you run it with real credentials and record the result.

Apple sign-in is currently iOS-only and local-session only. It is not yet backed by a Ross backend Apple auth route.

Real local model proof is still pending unless separately run and documented.

## What Ross does not do

Ross does not add:

- remote model APIs
- cloud OCR
- analytics SDKs
- remote case storage
- automatic case-file upload
- prompt upload
- OCR text upload
- filename upload
- party or client data upload

Ross is not presented as an AI lawyer and does not present outputs as legal advice.

## Repo layout

```text
ross/
  android/                  Android app shell and Compose workflow
  ios/                      iOS app shell and SwiftUI workflow
  backend/                  Auth, model catalog, download, and public-law routes
  core/rust/                Privacy and local AI boundary logic
  shared/                   Shared assets and schemas
  docs/                     Product, privacy, QA, and runbook docs
  scripts/                  Validation and development helpers
```

## Run the backend

Install dependencies once:

```bash
cd /Users/amanpandey/projects/ross/backend
npm install
```

Start the local backend:

```bash
cd /Users/amanpandey/projects/ross/backend
PORT=8787 ROSS_PUBLIC_BASE_URL=http://127.0.0.1:8787 npm run dev
```

Notes:

- Port `8080` is the default if it is free.
- The app can point to a different local backend from `Settings > Advanced > Save test server`.
- The backend exposes `GET /health` for a local smoke check.
- Current public-law search in dev is a privacy-safe backend fixture path, not a production research provider.

## Run iOS

Open [`ios/Ross.xcodeproj`](/Users/amanpandey/projects/ross/ios/Ross.xcodeproj) in Xcode and run the shared `Ross` scheme.

CLI build:

```bash
cd /Users/amanpandey/projects/ross/ios
xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' -derivedDataPath tmp/DerivedData build
swift test --scratch-path tmp/swiftpm
```

iOS local backend notes:

- iOS Simulator can reach `http://127.0.0.1:<port>` on the host machine.
- Physical iPhone testing should use your Mac's LAN IP, for example `http://192.168.x.x:8787`.
- The app also supports an in-app backend override under `Settings > Advanced`.

See [`ios/README.md`](/Users/amanpandey/projects/ross/ios/README.md) and [`docs/DEVICE_INSTALL_QA.md`](/Users/amanpandey/projects/ross/docs/DEVICE_INSTALL_QA.md).

## Run Android

Build from CLI:

```bash
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
./gradlew :app:testDebugUnitTest
```

Android local backend notes:

- The default emulator backend address is `http://10.0.2.2:8080`.
- If your backend runs elsewhere, use `Settings > Advanced > Save test server`.
- Physical Android devices should use your host machine's LAN IP.

See [`android/README.md`](/Users/amanpandey/projects/ross/android/README.md) and [`docs/DEVICE_INSTALL_QA.md`](/Users/amanpandey/projects/ross/docs/DEVICE_INSTALL_QA.md).

## Run privacy guards

```bash
cd /Users/amanpandey/projects/ross
./scripts/dev/verify-boundaries.sh
./scripts/ci/check-no-cloud-llm.sh
./scripts/ci/check-no-analytics.sh
./scripts/ci/check-no-large-model-assets.sh
./scripts/ci/check-onboarding-copy-boundary.sh
```

## QA and runbooks

- [`docs/INTERNAL_ALPHA_QA.md`](/Users/amanpandey/projects/ross/docs/INTERNAL_ALPHA_QA.md)
- [`docs/AUTH_QA.md`](/Users/amanpandey/projects/ross/docs/AUTH_QA.md)
- [`docs/DEVICE_INSTALL_QA.md`](/Users/amanpandey/projects/ross/docs/DEVICE_INSTALL_QA.md)
- [`docs/MANUAL_CASE_ASSOCIATE_E2E.md`](/Users/amanpandey/projects/ross/docs/MANUAL_CASE_ASSOCIATE_E2E.md)
- [`docs/PRIVACY_ARCHITECTURE.md`](/Users/amanpandey/projects/ross/docs/PRIVACY_ARCHITECTURE.md)
- [`docs/OFFLINE_BEHAVIOR.md`](/Users/amanpandey/projects/ross/docs/OFFLINE_BEHAVIOR.md)
- [`docs/NEXT_STEP_REPORT.md`](/Users/amanpandey/projects/ross/docs/NEXT_STEP_REPORT.md)

## Truth-in-status note

This internal alpha is about product usability and privacy boundaries.

It is honest to say:

- demo auth works for local QA
- the core shell exists across iOS and Android
- public-law preview is explicit and sanitized
- privacy guards are enforced in code and scripts

It is not honest to say, unless separately proven:

- real Google OAuth is fully proven
- Apple backend auth exists
- physical iPhone install is complete
- real local model proof is complete
