# Ross iOS Project

## Open and run in Xcode

1. Open `/Users/amanpandey/projects/ross/ios/Ross.xcodeproj` in Xcode.
2. Select the shared `Ross` scheme.
3. Pick any iOS Simulator destination.
4. Press Run.

The Xcode project reuses the existing SwiftUI sources in `/Users/amanpandey/projects/ross/ios/Ross` directly. `RossApp.swift` remains the app entry point for the iOS target.

## Command-line simulator build

From the repo root:

```sh
xcodebuild \
  -project ios/Ross.xcodeproj \
  -scheme Ross \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/tmp/DerivedData \
  build
```

## Screenshot export

Screenshot export is currently a macOS-hosted Swift Package workflow, not an iOS Simulator workflow. The iOS app target runs the interactive app UI; the PNG export path still comes from `ScreenshotExporter.swift`, which uses `AppKit` when available.

To export screenshots into `ios/tmp/ui-screenshots`, run from the `ios` directory:

```sh
cd /Users/amanpandey/projects/ross/ios
swift run Ross --generate-screenshots
```

That command writes these PNGs into `ios/tmp/ui-screenshots`:

- `ios-onboarding.png`
- `ios-private-ai-pack.png`
- `ios-workspace.png`
- `ios-ask-case.png`

If you instead launch the package from the repo root with `swift run --package-path ios Ross --generate-screenshots`, the same relative `tmp/ui-screenshots` folder is created under the repo root.
