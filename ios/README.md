# Ross iOS Project

## Open and run in Xcode

1. Open `/Users/amanpandey/projects/ross/ios/Ross.xcodeproj` in Xcode.
2. Select the shared `Ross` scheme.
3. Pick any iOS Simulator destination.
4. Press Run.

## Command-line build

```sh
cd /Users/amanpandey/projects/ross/ios
swift build --scratch-path tmp/swiftpm
xcodebuild -project Ross.xcodeproj -scheme Ross -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/DerivedData build
```

## Tests and screenshot export

```sh
cd /Users/amanpandey/projects/ross/ios
swift test --scratch-path tmp/swiftpm
swift run --scratch-path tmp/swiftpm Ross --generate-screenshots
```

## Current alpha foundation

- active alpha state is encrypted at rest
- PDF imports index native page text locally where available
- image imports run local Vision OCR where available
- iOS runs a local extraction orchestrator with:
  - acquisition
  - language profiling
  - prompt packing
  - deterministic fallback extraction
  - schema validation
  - verification and review queue generation
- public-law search and model-download clients remain privacy-safe

## Real local inference alpha status

- iOS now has a real-provider abstraction behind the installed-pack provider contract.
- An Apple Foundation Models adapter path exists behind availability checks.
- Real-runtime probing is disabled by default so CI and simulator runs stay deterministic.
- When the configured real runtime is unavailable, iOS falls back safely to the deterministic development provider.
- Invocation metadata stores hashes and runtime mode, not raw prompts or raw source text.

## Debug configuration

To exercise the real iOS runtime path manually, use scheme environment variables such as:

- `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
- `ROSS_LOCAL_RUNTIME=apple_foundation_models`
- `ROSS_LOCAL_MODEL_PATH=/absolute/path/to/local/model` when an external adapter file is required
- `ROSS_BACKEND_URL=http://127.0.0.1:8080`

No model file is committed to the repo, and CI does not require a real model artifact.

## Known caveats

- The Apple Foundation Models path is the only real inference path in this branch.
- It should not be claimed as active unless it actually ran on a compatible device or simulator host.
- Exact PDF snippet highlights remain best-effort, with source chips as the primary trust surface.
