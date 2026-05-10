# iOS Simulator QA Report

Date: 2026-05-03  
Branch: `codex/Gemma 4-gguf-model-strategy`  
Scope: iOS simulator pass for onboarding, matter workspace, document review, Ask Ross, private assistant setup/download, command routing, and public-law review behavior.

## Summary

Overall status: pass with high-priority product issues still open.

The product direction is much better than the earlier noisy build, but the current iOS app still has a few trust and usability breaks that matter more than polish:

- Ask Ross can still dominate the screen too easily with stacked result and composer surfaces.
- Some onboarding/setup screens are still layout-fragile.
- Document review remains too busy for fast legal verification.
- Matter/workspace state is cleaner, but scope and overlay behavior still need tightening.

This pass also confirmed one concrete trust bug and fixed it in code:

- Visible assistant `<think>` tags and malformed JSON should no longer leak into answer cards.

## Fixed In This Patch

### 1. Hidden reasoning leakage in Ask answers

Problem:
- When the local assistant returned malformed JSON, Ask Ross could fall back to raw text paragraphs.
- That allowed literal `<think>` tags and raw JSON fragments to become visible in the UI.

Fix:
- Added a dedicated Ask payload parser in `/Users/amanpandey/projects/ross/ios/Ross/AlphaFoundation/AlphaRootView.swift`.
- The parser now:
  - strips `<think>...</think>` blocks before display parsing,
  - attempts structured decode first,
  - salvages usable `headline`, `sections`, and `statusNote` from malformed JSON-like output,
  - rejects structured junk instead of rendering it directly,
  - only falls back to plain text when the text is actually human-readable.

Expected product result:
- Ross behaves more like a careful legal clerk and less like a runtime console when model output is imperfect.

### 2. Ask dock visual separation

Problem:
- The floating Ask dock could visually blend into the background, especially in light mode.

Fix:
- Updated the iOS and Android Ask dock surfaces to use a clearer floating treatment:
  - stronger border,
  - slightly deeper shadow,
  - softer glass lift,
  - more distinct surface separation from the screen behind it.
- On iOS, the dock now also gets a more visible blurred halo behind the card.

Files:
- `/Users/amanpandey/projects/ross/ios/Ross/AlphaFoundation/AlphaRootView.swift`
- `/Users/amanpandey/projects/ross/android/app/src/main/kotlin/com/ross/android/alpha/AlphaRossApp.kt`

## Simulator Findings

### P0

#### Ask answer rendering leaked internal model output

Status: fixed in this patch

Observed behavior:
- A normal legal question such as `What is the next hearing date?` could surface `<think>` tags and raw JSON-like content in the visible answer card or conversation UI.

Impact:
- This is a trust break. Lawyers should never see internal reasoning tags or malformed runtime output.

### P1

#### Ask/result surfaces still stack over the product

Observed behavior:
- Ask dock, inline answers, and other result surfaces can pile onto the same viewport and crowd out the underlying work.

Impact:
- The app feels more like overlays sitting on top of the work than a stable legal workbench.

Recommended next step:
- Keep one active Ask/result surface per screen.
- Collapse or dismiss stale inline responses more aggressively when scope changes.

#### Onboarding and assistant setup screens can clip horizontally

Observed behavior:
- `Set up Ross` and assistant-selection/setup surfaces were seen clipping off the right edge during simulator use.

Impact:
- These are first-run screens. Layout regressions here damage trust and comprehension early.

Recommended next step:
- Audit those flows at smaller iPhone widths and remove any content width assumptions.

#### Scope state can feel sticky

Observed behavior:
- Ask state can remain matter-scoped or carry stale result/context in places where the user expects a fresh global Ask surface.

Impact:
- Scope confusion is risky in a privacy-first legal app because it changes what Ross appears to be answering from.

Recommended next step:
- Reset or visibly reconcile Ask state when moving between global, matter, and file contexts.

### P2

#### Matter/notes surfaces still contain repeated or noisy copy

Observed behavior:
- Some sections still repeat explanatory lines or compete with chat/update modules in the same viewport.

Impact:
- The app becomes harder to skim.

#### Document review still tries to do too much at once

Observed behavior:
- Review stats, status, findings, preview, sources, raw text, and Ask can still compete in the same flow.

Impact:
- Verification takes more visual work than it should.

Recommended next step:
- Keep review actions dominant.
- Collapse raw text and sources by default.
- Reduce duplicate review summary copy.

#### Settings is improved but not fully flattened

Observed behavior:
- Surface copy is much better, but expanding diagnostics can still introduce layout weirdness and too much visible machinery.

Impact:
- Normal settings should remain layman-readable.

## Tested Flows

### Private assistant setup and readiness

Verified:
- assistant setup flow can progress,
- `Ross assistant is ready` appears in Settings,
- Privacy Log records:
  - `Assistant model download started`
  - `Assistant model verified`

### Typed commands

Verified:
- `add task call senior counsel`
  - local task created
- `save filing deadline on 1 May 2026`
  - date saved locally
- `save filing deadline May 10 2026`
  - failed safely with guidance
  - no silent mutation
- `draft chronology`
  - local draft/export path triggered

### Public-law review gate

Verified:
- public-law review preview appears before any send,
- sanitized preview path appears local-first,
- cancel path remains local,
- no direct network action was observed before explicit review/confirm.

### Ask Ross model-style query

Verified:
- the app can route a scoped legal question through the assistant path,
- the earlier rendering leak is now patched in code,
- follow-up visual validation should be rerun on simulator after this patch.

## Verification Results For This Patch

### iOS

- `xcodebuild -project ios/Ross.xcodeproj -scheme Ross -configuration Debug -destination 'platform=iOS Simulator,id=A5BDAF71-43EE-4566-A9A5-D1BC7B1FCC5F' -derivedDataPath ios/tmp/DerivedData build`
  - passed

### Android

- `./gradlew :app:compileDebugKotlin`
  - passed

## Test Coverage Note

iOS test files exist under:
- `/Users/amanpandey/projects/ross/ios/Tests/RossTests/AlphaExtractionTests.swift`
- `/Users/amanpandey/projects/ross/ios/Tests/RossTests/AlphaLawyerUsabilityTests.swift`

This patch added regression coverage for the Ask payload parser in:
- `/Users/amanpandey/projects/ross/ios/Tests/RossTests/AlphaExtractionTests.swift`

Added tests:
- `testMatterAskPayloadParserStripsThinkTagsAndSalvagesMalformedJSON`
- `testMatterAskPayloadParserFailsClosedForStructuredJunk`

Important caveat:
- The current Xcode project does not define a `RossTests` target or a test action for scheme `Ross`, so these tests are not runnable from the project as it stands.
- They are useful as source-level regression coverage, but the project still needs a real iOS test target before they can run in CI or locally through Xcode.

## Remaining Gaps

Not fully covered in this pass:

- failed / paused / broken model download states,
- selected-file Ask matrix in the current account state,
- fresh import -> reading state -> file-scoped Ask revalidation after latest UI changes,
- broader unsupported conversational phrasing matrix,
- post-patch visual recheck of every modified dock surface on both platforms,
- web app verification, because there is no standalone web frontend in this repo at the moment.

## Recommended Next Actions

1. Re-run simulator QA specifically on the Ask answer card after the `<think>` fix.
2. Simplify overlay stacking so only one Ask/result surface is active in a viewport at a time.
3. Fix onboarding/setup horizontal clipping.
4. Further compress document-review chrome and duplicate summary text.
5. Add a real `RossTests` target to the iOS project so the existing test suite can actually run.
