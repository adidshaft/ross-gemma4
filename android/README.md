# Ross Android Project

## Build from CLI

```sh
cd /Users/amanpandey/projects/ross/android
./gradlew :app:assembleDebug
```

## Run unit tests

```sh
cd /Users/amanpandey/projects/ross/android
./gradlew :app:testDebugUnitTest
```

## Current Android usability alpha

The active Android shell is lawyer-facing and organized around:

- Home
- Cases
- Capture / Import
- Ask Ross
- Settings

Key Android behaviors in this phase:

- Home dashboard with cases, tasks, dates, review items, and recent documents
- local task persistence
- case workspaces with documents, tasks, review, and exports
- plain-language document status copy
- sticky Ask Ross bar
- Web toggle with sanitized preview and confirmation
- privacy ledger in plain language
- technical diagnostics hidden under advanced Private AI settings

## Privacy and Web search

Android keeps these rules:

- case files stay on this device
- Web is off by default
- no public-law request is made when Web is off
- when Web is on, Ross shows a sanitized preview before search
- public-law results stay labeled separately from case-file sources

## Private AI note

Private AI Pack setup remains available with:

- Quick Start
- Case Associate
- Senior Drafting Support

Normal Android screens should not expose runtime identifiers. Technical diagnostics remain under advanced settings.

## Real local inference note

Real local-model proof is still separate from this usability alpha.

This README documents the Android product shell now in place, not a claim that a real Android runtime has already been proven on hardware in this phase.
