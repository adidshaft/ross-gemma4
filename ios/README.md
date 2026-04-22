# Ross iOS

## Open and run

1. Open [`ios/Ross.xcodeproj`](/Users/amanpandey/projects/ross/ios/Ross.xcodeproj) in Xcode.
2. Select the shared `Ross` scheme.
3. Pick an iPhone simulator or a provisioned device.
4. Run.

CLI build:

```bash
cd /Users/amanpandey/projects/ross/ios
xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.4.1' -derivedDataPath tmp/DerivedData build
swift test --scratch-path tmp/swiftpm
```

## Current iOS launch flow

The intended lawyer-facing flow is:

1. Language selection
2. Sign in
3. Optional quick unlock
4. Home

The supported local QA path is `Open demo mode`.

## Demo mode

Demo mode:

- works without backend credentials
- creates a local session
- seeds a synthetic workspace
- is for local testing only

Current seeded content includes:

- `Demo Matter: Sharma v. Rana`
- documents, tasks, dates, and review items

Reset path:

- `Settings > Account > Reset demo data`

## Sign-in modes

### Google sign-in

- backend-mediated OAuth flow is wired
- callback scheme is `ross://auth/callback`
- URL scheme `ross` remains registered in [`ios/Ross/Resources/Info.plist`](/Users/amanpandey/projects/ross/ios/Ross/Resources/Info.plist)
- real credentials are still required for a real proof run

Until a real credential run is performed, treat Google OAuth as ready for manual QA, not proven.

### Apple sign-in

- available on iOS only
- currently creates a local Ross session on device
- does not yet use a Ross backend Apple auth route

Normal UI should be interpreted as local-only for now, not cross-device account sync.

### Quick unlock

- uses LocalAuthentication
- simulator support is limited
- physical-device proof is still required for a real manual claim

## Backend connectivity

iOS resolves backend URLs in this order:

1. saved test-server override in Settings
2. `ROSS_BACKEND_BASE_URL`
3. `ROSS_BACKEND_URL`
4. default `http://127.0.0.1:8080`

Recommended local setup:

- iOS Simulator: `http://127.0.0.1:8081` in this session
- physical iPhone: `http://<your-mac-lan-ip>:8081`

The app supports changing the server from `Settings > Advanced > Save test server`.

## Public-law search

- `Web search` is off by default
- Ross builds the public-law query locally
- Ross shows a preview before anything is sent
- explicit confirmation is required
- only the approved sanitized public-law query crosses the boundary

Legal citations now preserved by tests include:

- `Order 39 Rules 1 and 2 CPC`
- `Section 138 NI Act`
- `Section 482 CrPC`
- `Article 226 Constitution of India`

If the backend is configured with `ROSS_PUBLIC_LAW_GEMINI_API_KEY` or `GEMINI_API_KEY`, the confirmed public-law request is resolved server-side through Gemini with Google Search grounding.

If no live connector is available, Ross falls back to a privacy-safe backend index for QA.

## Current iOS truth on April 23, 2026

Freshly observed in this pass:

- demo sign-in lands on Home
- Home shows a populated daily dashboard
- create matter
- Ask Ross add-task action
- Ask Ross save-next-hearing action
- matter workspace opens
- the real import picker is reachable
- seeded document viewer and review surface reopen
- plain-language `Accept`, `Edit`, and `Ignore` review controls are visible

Freshly observed blocker:

- inline review action taps in the simulator are currently unreliable in this environment and repeatedly throw Ross to SpringBoard instead of proving review state changes

Still not freshly proven on iOS in this pass:

- review `Accept`
- review `Edit`
- review `Ignore`
- review-to-task/date
- export generation and export opening
- Privacy Ledger opening
- Settings -> Advanced
- public-law preview -> confirm -> results after the latest citation/layout fixes

## Xcode test-action note

`xcodebuild test` is still limited because the shared `Ross` scheme has no Xcode-native test target in `Testables`.

The safe validation path for now remains:

- `xcodebuild ... build`
- `swift test --scratch-path tmp/swiftpm`

See [`docs/PRODUCT_PROOF_QA.md`](/Users/amanpandey/projects/ross/docs/PRODUCT_PROOF_QA.md), [`docs/AUTH_QA.md`](/Users/amanpandey/projects/ross/docs/AUTH_QA.md), and [`docs/REAL_WORLD_USAGE_QA.md`](/Users/amanpandey/projects/ross/docs/REAL_WORLD_USAGE_QA.md).
