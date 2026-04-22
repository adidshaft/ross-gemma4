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

The target internal-alpha launch flow is:

1. Language selection
2. Sign in
3. Optional quick unlock
4. Home

The supported local QA path is `Open demo mode`.

## Sign-in modes

### Demo mode

- works without backend credentials
- creates a local session
- is for local testing only
- should not be described as a production account

Use `advocate@ross.ai` on the demo path.

### Google sign-in

- backend-mediated OAuth flow is wired
- custom callback scheme is `ross://auth/callback`
- bundle URL scheme `ross` is registered in [`ios/Ross/Resources/Info.plist`](/Users/amanpandey/projects/ross/ios/Ross/Resources/Info.plist)
- real credentials are required for a true proof run

Until a real credential run is performed, treat Google OAuth as ready for manual QA, not proven.

### Apple sign-in

- available on iOS only
- currently creates a local Ross session on device
- does not yet use a Ross backend Apple auth route

Normal UI should be read as local-only for now, not cross-device account sync.

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

Recommended local development setup:

- iOS Simulator: `http://127.0.0.1:8787`
- Physical iPhone: `http://<your-mac-lan-ip>:8787`

The app also allows changing the server from `Settings > Advanced > Save test server`.

`NSAllowsLocalNetworking` is enabled for local-network testing.

## Public-law search

- Web is off by default
- Ross builds the public-law query locally
- Ross shows a preview before anything is sent
- the user must confirm
- only a sanitized public-law query crosses the boundary

If the backend is configured with `ROSS_PUBLIC_LAW_GEMINI_API_KEY` or `GEMINI_API_KEY`, the confirmed public-law request is resolved server-side through Gemini with Google Search grounding.

If that key is missing, Ross falls back to privacy-safe fixture results for QA. Either path keeps case files and document text on device.

## Private AI note

Normal iOS screens should show plain-language status such as:

- `Ready`
- `Not installed`
- `Downloading`
- `Waiting for Wi-Fi`
- `Needs attention`
- `Using basic local mode`

Technical diagnostics stay under `Settings > Advanced > Technical diagnostics`.

## Still unproven on iOS

- real Google OAuth with real credentials
- backend-backed Apple sign-in
- physical iPhone install and provisioning completion
- real local model proof on device

See [`docs/AUTH_QA.md`](/Users/amanpandey/projects/ross/docs/AUTH_QA.md) and [`docs/DEVICE_INSTALL_QA.md`](/Users/amanpandey/projects/ross/docs/DEVICE_INSTALL_QA.md).
