# Ross iOS Project

## Open and run in Xcode

1. Open `/Users/amanpandey/projects/ross/ios/Ross.xcodeproj` in Xcode.
2. Select the shared `Ross` scheme.
3. Pick an iOS Simulator destination.
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

## Current iOS usability alpha

The active iOS shell is lawyer-facing and organized around:

- Home
- Cases
- Capture / Import
- Ask Ross
- Settings

Key iOS behaviors in this phase:

- Home dashboard with cases, tasks, dates, review items, and recent documents
- local task model and case-scoped task views
- case workspaces with overview, documents, tasks, review, and exports
- plain-language document statuses
- bottom Ask Ross composer
- Web toggle with sanitized preview and confirmation
- privacy ledger in plain language
- technical diagnostics hidden under advanced Private AI settings

## Privacy and Web search

iOS keeps these rules:

- case files stay on this device
- Web is off by default
- no public-law request is made when Web is off
- when Web is on, Ross shows a sanitized preview before search
- public-law results stay separate from case-file sources

## Private AI note

Private AI Pack setup remains available with:

- Quick Start
- Case Associate
- Senior Drafting Support

Normal iOS screens should avoid runtime jargon. Technical diagnostics remain in advanced settings for QA and proof work.

## Real local inference note

Real local-model proof is still separate from this usability alpha.

This README describes the current iOS product shell and validation entry points, not a claim that a real iOS runtime has already been proven on hardware in this phase.
