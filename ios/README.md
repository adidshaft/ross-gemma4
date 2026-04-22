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

- iOS Simulator: `http://127.0.0.1:8787`
- physical iPhone: `http://<your-mac-lan-ip>:8787`

The app supports changing the server from `Settings > Advanced > Save test server`.

## Public-law search

- `Web search` is off by default
- Ross builds the public-law query locally
- Ross shows a preview before anything is sent
- explicit confirmation is required
- only a sanitized public-law query crosses the boundary

If the backend is configured with `ROSS_PUBLIC_LAW_GEMINI_API_KEY` or `GEMINI_API_KEY`, the confirmed public-law request is resolved server-side through Gemini with Google Search grounding.

If no live connector is available, Ross falls back to a privacy-safe backend index for QA.

## Current iOS truth

Freshly observed in this phase:

- demo sign-in lands on Home
- Home shows real local dashboard state
- matter list opens
- matter workspace opens
- file room opens
- document viewer opens
- Privacy Ledger opens
- notes and exports surface opens

Still unproven on iOS:

- real Google OAuth with real credentials
- backend-backed Apple sign-in
- physical iPhone install and provisioning completion
- quick unlock on physical hardware
- real local model proof on device

## Xcode test-action note

`xcodebuild test` is still limited because the shared `Ross` scheme has no Xcode testables. The safe validation path for now remains:

- `xcodebuild ... build`
- `swift test --scratch-path tmp/swiftpm`

See [`docs/AUTH_QA.md`](/Users/amanpandey/projects/ross/docs/AUTH_QA.md), [`docs/DEVICE_INSTALL_QA.md`](/Users/amanpandey/projects/ross/docs/DEVICE_INSTALL_QA.md), and [`docs/REAL_WORLD_USAGE_QA.md`](/Users/amanpandey/projects/ross/docs/REAL_WORLD_USAGE_QA.md).
